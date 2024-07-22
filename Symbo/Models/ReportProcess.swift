//
//  ReportProcess.swift
//  MacSymbolicator
//

import Foundation

public class ReportProcess {
    let name: String?
    private(set) var architecture: Architecture?
    let binaryImages: [BinaryImage]
    let stackFrames: [StackFrame]

    private static let processSectionRegex = #"^(Process:.*?)(?=\z|^Process:)"#
    private static let processNameRegex = #"^Process:\s*(.+?)\s*\["#

    lazy var binariesForSymbolication: [BinaryImage] = {
        let images = stackFrames.map { $0.binaryImage }
        return Array(Set<BinaryImage>(images))
    }()

    lazy var uuidsForSymbolication: [BinaryUUID] = {
        let uuids = stackFrames.map { $0.binaryImage.uuid }
        return Array(Set<BinaryUUID>(uuids))
    }()

    static func find(in content: String) -> [ReportProcess] {
        let processSections = content.scan(
            pattern: processSectionRegex,
            options: [.caseInsensitive, .anchorsMatchLines, .dotMatchesLineSeparators]
        )

        return processSections.compactMap {
            guard let match = $0.first else { return nil }
            return ReportProcess(parsing: match)
        }
    }

    init?(parsing content: String) {
        name = content.scan(pattern: Self.processNameRegex).first?.first
        architecture = Architecture.find(in: content)
        binaryImages = BinaryImage.find(in: content)
        stackFrames = StackFrame.find(in: content, binaryImageMap: BinaryImageMap(binaryImages: binaryImages))
    }
}
