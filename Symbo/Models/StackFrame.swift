//
//  StackFrame.swift
//  MacSymbolicator
//

import Foundation

class StackFrame {
    private enum Parsing {
        static let lineRegex = #"^\d+\s+.*?0x.*?\s.*?\s\+\s.*$"#
        static let componentsRegex = #"^\d+\s+(.*?)\s+(0x.*?)\s(.*?)\s\+\s(.*)"#
    }

    let originalLine: String
    let cryptedAddress: String
    var symbolicatedAddress: String?

    let binaryImage: BinaryImage
    let byteOffset: String

    init?(parsingLine line: String, binaryImageMap: BinaryImageMap) {
        self.originalLine = line

        guard let components = line.scan(
            pattern: Parsing.componentsRegex,
            options: [.caseInsensitive]
        ).first, components.count == 4 else {
            return nil
        }

        cryptedAddress = components[1]
        let loadAddressOrTargetName = components[2]
        byteOffset = components[3]

        guard let binaryImage = binaryImageMap.binaryImage(forLoadAddress: loadAddressOrTargetName) ??
                  binaryImageMap.binaryImage(forName: loadAddressOrTargetName) else {
            return nil
        }

        self.binaryImage = binaryImage
    }

    func symbolicateLine(with symbolicatedAddress: String) -> String {
        let newLine = originalLine.replacingOccurrences(of: binaryImage.loadAddress, with: symbolicatedAddress)

        let marker = ">>>> "
        let spacesBeforeAddress = String(repeating: " ", count: 5)

        if let range = newLine.range(of: spacesBeforeAddress + cryptedAddress) {
            return newLine.replacingCharacters(in: range, with: marker + cryptedAddress)
        } else {
            return newLine.replacingOccurrences(of: cryptedAddress, with: marker + cryptedAddress)
        }
    }

    static func find(in content: String, binaryImageMap: BinaryImageMap) -> [StackFrame] {
        let lines = content.scan(
            pattern: Parsing.lineRegex,
            options: [.caseInsensitive, .anchorsMatchLines]
        )

        return lines.compactMap { result -> StackFrame? in
            guard let line = result.first else { return nil }
            return StackFrame(parsingLine: line, binaryImageMap: binaryImageMap)
        }
    }
}
