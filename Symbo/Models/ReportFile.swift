//
//  ReportFile.swift
//  MacSymbolicator
//

import Foundation

public class ReportFile {
    enum InitializationError: Error {
        case readingFile(Error)
        case emptyFile
        case translation(Translator.Error)
        case other(Error)
    }

    let path: URL
    let filename: String
    let processes: [ReportProcess]

    lazy var uuidsForSymbolication: [BinaryUUID] = {
        processes.flatMap { $0.uuidsForSymbolication }
    }()

    let content: String
    var symbolicatedContent: String?

    var symbolicatedContentSaveURL: URL {
        let directory = path.deletingLastPathComponent()
        let originalFilename = path.lastPathComponent
        let newFilename = "[S] " + (originalFilename as NSString).deletingPathExtension + ".txt"
        return directory.appendingPathComponent(newFilename)
    }

    public init(path: URL) throws {
        let originalContent: String

        do {
            originalContent = try String(contentsOf: path, encoding: .utf8)
        } catch {
            throw InitializationError.readingFile(error)
        }

        guard !originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InitializationError.emptyFile
        }

        self.path = path
        self.filename = path.lastPathComponent

        // Convert to TXT format
        do {
            self.content = try Self.convertToTXTFormat(originalContent, path: path)
        } catch {
            throw InitializationError.translation(error as? Translator.Error ?? .unexpectedOutput)
        }

        // Initialize processes after content is set
        self.processes = ReportProcess.find(in: self.content)
    }

    private static func convertToTXTFormat(_ content: String, path: URL) throws -> String {
        // If it's already in TXT format, return as is
        if !content.hasPrefix("{") {
            return content
        }

        // If it's in IPS format, convert to TXT
        return try Translator.translatedCrash(forIPSAt: path)
    }
}
