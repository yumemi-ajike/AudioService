//
//  AudioService.swift
//  AudioService
//
//  Created by Atsushi Jike on 2018/09/05.
//  Copyright © 2018年 Atsushi Jike. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

extension Notification.Name {
    static let audioServiceDidUpdateData = Notification.Name(rawValue: "AudioServiceDidUpdateDataNotification")
}

func AQAudioQueueInputCallback(inUserData: UnsafeMutableRawPointer?,
                               inAQ: AudioQueueRef,
                               inBuffer: AudioQueueBufferRef,
                               inStartTime: UnsafePointer<AudioTimeStamp>,
                               inNumberPacketDescriptions: UInt32,
                               inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?) {
    let audioService = unsafeBitCast(inUserData!, to:AudioService.self)
    audioService.writePackets(inBuffer: inBuffer)
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil);
    
    print("startingPacketCount: \(audioService.startingPacketCount), maxPacketCount: \(audioService.maxPacketCount)")
    if (audioService.maxPacketCount <= audioService.startingPacketCount) {
        audioService.stopRecord()
    }
}

func AQAudioQueueOutputCallback(inUserData: UnsafeMutableRawPointer?,
                                inAQ: AudioQueueRef,
                                inBuffer: AudioQueueBufferRef) {
    let audioService = unsafeBitCast(inUserData!, to:AudioService.self)
    audioService.readPackets(inBuffer: inBuffer)
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil);
    
    print("startingPacketCount: \(audioService.startingPacketCount), maxPacketCount: \(audioService.maxPacketCount)")
    if (audioService.maxPacketCount <= audioService.startingPacketCount) {
        audioService.startingPacketCount = 0;
    }
}

class AudioService {
    var buffer: UnsafeMutableRawPointer
    var audioQueueObject: AudioQueueRef?
    let numPacketsToRead: UInt32 = 1024
    let numPacketsToWrite: UInt32 = 1024
    var startingPacketCount: UInt32
    var maxPacketCount: UInt32
    let bytesPerPacket: UInt32 = 2
    let seconds: UInt32 = 10
    var audioFormat: AudioStreamBasicDescription {
        return AudioStreamBasicDescription(mSampleRate: 48000.0,
                                           mFormatID: kAudioFormatLinearPCM,
                                           mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked),
                                           mBytesPerPacket: 2,
                                           mFramesPerPacket: 1,
                                           mBytesPerFrame: 2,
                                           mChannelsPerFrame: 1,
                                           mBitsPerChannel: 16,
                                           mReserved: 0)
    }
    var data: NSData? {
        didSet {
            NotificationCenter.default.post(name: .audioServiceDidUpdateData, object: self)
        }
    }

    init(_ obj: Any?) {
        startingPacketCount = 0
        maxPacketCount = (48000 * seconds)
        buffer = UnsafeMutableRawPointer(malloc(Int(maxPacketCount * bytesPerPacket)))
    }

    deinit {
        buffer.deallocate()
    }

    func startRecord() {
        print("startRecord")
        guard audioQueueObject == nil else  { return }
        data = nil
        prepareForRecord()
        let err: OSStatus = AudioQueueStart(audioQueueObject!, nil)
        print("err: \(err)")
    }

    func stopRecord() {
        data = NSData(bytesNoCopy: buffer, length: Int(maxPacketCount * bytesPerPacket))
        AudioQueueStop(audioQueueObject!, true)
        AudioQueueDispose(audioQueueObject!, true)
        audioQueueObject = nil
    }
    
    func play() {
        guard audioQueueObject == nil else  { return }
        prepareForPlay()
        let err: OSStatus = AudioQueueStart(audioQueueObject!, nil)
        print("err: \(err)")
    }

    func stop() {
        AudioQueueStop(audioQueueObject!, true)
        AudioQueueDispose(audioQueueObject!, true)
        audioQueueObject = nil
    }

    func setData(_ data: NSMutableData) {
        self.data = data.copy() as? NSData
        memcpy(buffer, data.mutableBytes, Int(maxPacketCount * bytesPerPacket))
    }

    private func prepareForRecord() {
        print("prepareForRecord")
        var audioFormat = self.audioFormat
    
        AudioQueueNewInput(&audioFormat,
                           AQAudioQueueInputCallback,
                           unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                           CFRunLoopGetCurrent(),
                           CFRunLoopMode.commonModes.rawValue,
                           0,
                           &audioQueueObject)
        
        startingPacketCount = 0;
        var buffers = Array<AudioQueueBufferRef?>(repeating: nil, count: 3)
        let bufferByteSize: UInt32 = numPacketsToWrite * audioFormat.mBytesPerPacket
        
        for bufferIndex in 0 ..< buffers.count {
            AudioQueueAllocateBuffer(audioQueueObject!, bufferByteSize, &buffers[bufferIndex])
            AudioQueueEnqueueBuffer(audioQueueObject!, buffers[bufferIndex]!, 0, nil)
        }
    }
    
    private func prepareForPlay() {
        print("prepareForPlay")
        var audioFormat = self.audioFormat
    
        AudioQueueNewOutput(&audioFormat,
                            AQAudioQueueOutputCallback,
                            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                            CFRunLoopGetCurrent(),
                            CFRunLoopMode.commonModes.rawValue,
                            0,
                            &audioQueueObject)
        
        startingPacketCount = 0
        var buffers = Array<AudioQueueBufferRef?>(repeating: nil, count: 3)
        let bufferByteSize: UInt32 = numPacketsToRead * audioFormat.mBytesPerPacket
    
        for bufferIndex in 0 ..< buffers.count {
            AudioQueueAllocateBuffer(audioQueueObject!, bufferByteSize, &buffers[bufferIndex])
            AQAudioQueueOutputCallback(inUserData: unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                                       inAQ: audioQueueObject!,
                                       inBuffer: buffers[bufferIndex]!)
        }
    }

    func readPackets(inBuffer: AudioQueueBufferRef) {
        print("readPackets")
        var numPackets: UInt32 = maxPacketCount - startingPacketCount
        if numPacketsToRead < numPackets {
            numPackets = numPacketsToRead
        }
        
        if 0 < numPackets {
            memcpy(inBuffer.pointee.mAudioData,
                   buffer.advanced(by: Int(bytesPerPacket * startingPacketCount)),
                   (Int(bytesPerPacket * numPackets)))
            inBuffer.pointee.mAudioDataByteSize = (bytesPerPacket * numPackets)
            inBuffer.pointee.mPacketDescriptionCount = numPackets
            startingPacketCount += numPackets
        }
        else {
            inBuffer.pointee.mAudioDataByteSize = 0;
            inBuffer.pointee.mPacketDescriptionCount = 0;
        }
    }
    
    func writePackets(inBuffer: AudioQueueBufferRef) {
        print("writePackets")
        print("writePackets mAudioDataByteSize: \(inBuffer.pointee.mAudioDataByteSize), numPackets: \(inBuffer.pointee.mAudioDataByteSize / 2)")
        var numPackets: UInt32 = (inBuffer.pointee.mAudioDataByteSize / bytesPerPacket)
        if ((maxPacketCount - startingPacketCount) < numPackets) {
            numPackets = (maxPacketCount - startingPacketCount)
        }
        
        if 0 < numPackets {
            memcpy(buffer.advanced(by: Int(bytesPerPacket * startingPacketCount)),
                   inBuffer.pointee.mAudioData,
                   Int(bytesPerPacket * numPackets))
            startingPacketCount += numPackets;
        }
    }
}
