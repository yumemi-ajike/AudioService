//
//  AppDelegate.swift
//  AudioService
//
//  Created by Atsushi Jike on 2018/09/05.
//  Copyright © 2018年 Atsushi Jike. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var waveView: WaveView!
    private let audioService = AudioService(nil)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(audioServiceDidUpdateData), name: .audioServiceDidUpdateData, object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }

    @IBAction func record(_ sender: Any) {
        audioService.startRecord()
    }
    
    @IBAction func stopRecord(_ sender: Any) {
        audioService.stopRecord()
    }

    @IBAction func play(_ sender: Any) {
        audioService.play()
    }

    @IBAction func stop(_ sender: Any) {
        audioService.stop()
    }

    @IBAction func exportData(_ sender: Any) {
        guard let data = audioService.data else { return }
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "sound.raw"
        savePanel.begin { (result) in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let url = savePanel.url else { return }
                data.write(to: url, atomically: true)
            }
        }
    }

    @IBAction func importData(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["raw"]
        openPanel.begin { [weak self] (result) in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let `self` = self, let url = openPanel.url, let data = NSMutableData(contentsOf: url) else { return }
                self.audioService.setData(data)
            }
        }
    }
    
    @objc private func audioServiceDidUpdateData(notification: Notification) {
        waveView.data = audioService.data
    }
}

