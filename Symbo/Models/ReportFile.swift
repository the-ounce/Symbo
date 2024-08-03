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

    let path: URL?
    let filename: String
    let processes: [ReportProcess]

    lazy var uuidsForSymbolication: [BinaryUUID] = {
        processes.flatMap { $0.uuidsForSymbolication }
    }()

    let content: String
    var symbolicatedContent: String?

    var symbolicatedContentSaveURL: URL {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!

        if let path = path {
            let originalFilename = path.lastPathComponent
            let newFilename = "[S] " + (originalFilename as NSString).deletingPathExtension + ".crash"
            return desktopURL.appendingPathComponent(newFilename)
        } else {
            return desktopURL.appendingPathComponent("[S] Untitled.crash")
        }
    }

    public convenience init(path: URL) throws {
        let originalContent: String

        do {
            originalContent = try String(contentsOf: path, encoding: .utf8)
        } catch {
            throw InitializationError.readingFile(error)
        }

        try self.init(content: originalContent, path: path)
    }

    public init(content: String, path: URL? = nil) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InitializationError.emptyFile
        }

        self.path = path
        self.filename = path?.lastPathComponent ?? "Untitled"

        // Convert to TXT format
        do {
            self.content = try Self.convertToTXTFormat(content, path: path)
        } catch {
            throw InitializationError.translation(error as? Translator.Error ?? .unexpectedOutput)
        }

        // Initialize processes after content is set
        self.processes = ReportProcess.find(in: self.content)
    }

    private static func convertToTXTFormat(_ content: String, path: URL?) throws -> String {
        // If it's already in TXT format, return as is
        if !content.hasPrefix("{") {
            return content
        }

        // If it's in IPS format, convert to TXT
        if let path = path {
            return try Translator.translatedCrash(forIPSAt: path)
        } else {
            // For content without a file path, we need to handle IPS conversion differently
            // This might require modifying the Translator class to handle string input
            // For now, we'll just return the original content
            return content
        }
    }
}
