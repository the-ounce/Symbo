//
//  FolderAccessTrigger.swift
//  Symbo
//
//  Created by Mykyta Havrylenko on 03.08.2024.
//

import Foundation

class FolderAccessTrigger {
    static func triggerAccessAlerts(completion: @escaping () -> Void) {
        let folderURLs = [
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        accessFolders(folderURLs, completion: completion)
    }

    private static func accessFolders(_ folderURLs: [URL], completion: @escaping () -> Void) {
        guard let folderURL = folderURLs.first else {
            completion()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // This will trigger the system alert if permission hasn't been granted
            _ = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

            DispatchQueue.main.async {
                accessFolders(Array(folderURLs.dropFirst()), completion: completion)
            }
        }
    }
}
