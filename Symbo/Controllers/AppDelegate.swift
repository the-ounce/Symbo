//
//  AppDelegate.swift
//  MacSymbolicator
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let mainController = MainController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Updates.availableUpdate(forUser: "inket", repository: "MacSymbolicator") { [weak self] release, error in
            if let release = release {
                self?.mainController.suggestUpdate(version: release.version.string, url: release.url)
            } else if let error = error {
                print("Error checking for updates: \(error)")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first {
            window.makeKeyAndOrderFront(self)
        }
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        mainController.openFile(filename)
    }
}
