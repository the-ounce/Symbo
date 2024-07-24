//
//  DSYMFile.swift
//  MacSymbolicator
//

import Foundation

public struct DSYMFile: Equatable {
    let path: URL
    let filename: String
    let uuids: [BinaryUUID: String]
    let binaryPaths: [String]

    var binaryPathsDescription: String {
        return binaryPaths.joined(separator: ", ")
    }

    public static func dsymFiles(from url: URL) -> [DSYMFile] {
        if let file = DSYMFile(path: url) {
            return [file]
        } else {
            // Maybe embedded DSYM files created by fastlane. See https://github.com/inket/MacSymbolicator/issues/21
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []

            return entries.compactMap {
                guard $0.lowercased().hasSuffix(".dsym") else { return nil }
                return DSYMFile(path: url.appendingPathComponent($0))
            }
        }
    }

    init?(path: URL) {
        self.path = path
        self.filename = path.lastPathComponent

        // Initialize binaryPaths
        let dwarfPath = path.appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("DWARF")

        if let binaries = try? FileManager.default.contentsOfDirectory(atPath: dwarfPath.path) {
            self.binaryPaths = binaries.map { dwarfPath.appendingPathComponent($0).path }
        } else {
            self.binaryPaths = [path.path]
        }

        // Initialize uuids
        let result = "dwarfdump --uuid '\(path.path)'".run()
        let output = result.output?.trimmed

        if output == "", (result.error ?? "").trimmed != "" {
            return nil
        }

        var uuids = [BinaryUUID: String]()

        output?.components(separatedBy: .newlines).forEach { line in
            guard
                let match = line.scan(pattern: #"UUID: (.*?) \((.*?)\) (.*)"#).first,
                match.count == 3,
                let uuid = BinaryUUID(match[0])
            else { return }

            let binaryName = match[2]
            uuids[uuid] = binaryName
        }

        self.uuids = uuids
    }
}

extension DSYMFile {
    mutating func selectBinary(forProcessName processName: String,
                               uuid: BinaryUUID? = nil,
                               architecture: String? = nil) -> String? {
        for binaryPath in binaryPaths {
            let binaryName = URL(fileURLWithPath: binaryPath).lastPathComponent

            // Check if the binary name matches the process name
            if binaryName == processName {
                return binaryPath
            }
        }
        return nil
    }
}
