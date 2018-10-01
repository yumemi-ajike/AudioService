//
//  WaveView.swift
//  AudioService
//
//  Created by 寺家 篤史 on 2018/10/01.
//  Copyright © 2018年 Atsushi Jike. All rights reserved.
//

import Cocoa

final class WaveView: NSView {
    var data: NSData? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.set()
        NSBezierPath(rect: bounds).fill()
        NSColor.darkGray.set()
        NSBezierPath(rect: bounds).stroke()

        guard let data = data else { return }

        let bezierPath = NSBezierPath()
        let length = data.length
        let unit = bounds.width / CGFloat(length)
        let mid = bounds.height / 2
        let bytes = UnsafeBufferPointer(start: data.bytes.assumingMemoryBound(to: Int8.self), count: length)

        bezierPath.move(to: NSPoint(x: 0, y: mid))
        for index in 0 ..< length {
            let normaliedSample = 100 * CGFloat(bytes[index]) / 128
            bezierPath.line(to: NSPoint(x: unit * CGFloat(index), y: (normaliedSample * CGFloat(mid / 128)) + mid))
        }
        NSColor.black.set()
        bezierPath.lineWidth = 1
        bezierPath.stroke()
    }
}
