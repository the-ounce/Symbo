//
//  Symbolicator.swift
//  MacSymbolicator
//

import Cocoa

struct Symbolicator {
    let reportFile: ReportFile
    let dsymFiles: [DSYMFile]

    var symbolicatedContent: NSAttributedString?
    var logController: LogController

    init(reportFile: ReportFile, dsymFiles: [DSYMFile], logController: LogController) {
        self.reportFile = reportFile
        self.dsymFiles = dsymFiles
        self.logController = logController
    }

    mutating func symbolicate() -> Bool {
        logController.resetLogs()

        var hasFailed = false

        reportFile.processes.forEach { process in
            if symbolicateProcess(process) == false {
                hasFailed = true
            }
        }

        updateSymbolicatedContent()

        return !hasFailed
    }

    mutating func symbolicateProcess(_ process: ReportProcess) -> Bool {
        logInitialMessage(for: process)

        guard let architecture = process.architecture else {
            logController.addLogMessage("Could not detect process architecture.")
            return false
        }

        if !canSymbolicate(process) {
            return false
        }

        let (_, dsymsByLoadAddress) = createDSymMappings(for: process)
        logMissingDSyms(process: process, dsymsByLoadAddress: dsymsByLoadAddress)

        guard !dsymsByLoadAddress.isEmpty else {
            logController.addLogMessage("No matching dSYMs found for symbolicating \(process.name ?? "<null>")")
            return true
        }

        return symbolicateStackFrames(process: process,
                                      architecture: architecture,
                                      dsymsByLoadAddress: dsymsByLoadAddress)
    }

    private func logInitialMessage(for process: ReportProcess) {
        logController.addLogMessage("""
        —————————————————————————————————————————————————
        * Symbolicating process \(process.name ?? "<null>")
        """)
    }

    private func canSymbolicate(_ process: ReportProcess) -> Bool {
        if !process.stackFrames.isEmpty && process.binaryImages.isEmpty {
            logController.addLogMessage("""
            Could not detect application binary images for reported process \(process.name ?? "<null>").\
            Application might have crashed during launch.
            """)
            return false
        }

        if process.stackFrames.isEmpty {
            logController.addLogMessage("""
            Did not find anything to symbolicate for process \(process.name ?? "<null>").
            """)
            return false
        }

        return true
    }

    private func createDSymMappings(for process: ReportProcess) -> ([BinaryUUID: DSYMFile], [String: DSYMFile]) {
        var dsymsByUUID = [BinaryUUID: DSYMFile]()
        var dsymsByLoadAddress = [String: DSYMFile]()

        for dsymFile in dsymFiles {
            for (uuid, _) in dsymFile.uuids {
                dsymsByUUID[uuid] = dsymFile
            }
        }

        for binaryImage in process.binaryImages {
            if let dsymFile = dsymsByUUID[binaryImage.uuid] {
                dsymsByLoadAddress[binaryImage.loadAddress] = dsymFile
            }
        }

        return (dsymsByUUID, dsymsByLoadAddress)
    }

    private func logMissingDSyms(process: ReportProcess, dsymsByLoadAddress: [String: DSYMFile]) {
        let missingDSYMs = process.binaryImages.filter { dsymsByLoadAddress[$0.loadAddress] == nil }
        for missingBinary in missingDSYMs {
            logController.addLogMessage("Missing dSYM for binary: \(missingBinary.name), \(missingBinary.uuid.pretty)")
        }
    }

    private func symbolicateStackFrames(process: ReportProcess,
                                        architecture: Architecture,
                                        dsymsByLoadAddress: [String: DSYMFile]) -> Bool {
        var hasFailed = false

        for frame in process.stackFrames {
            guard var dsymFile = dsymsByLoadAddress[frame.binaryImage.loadAddress] else { continue }

            guard let selectedBinaryPath = dsymFile.selectBinary(
                forProcessName: frame.binaryImage.name,
                uuid: frame.binaryImage.uuid,
                architecture: architecture.atosString
            ) else {
                logController.addLogMessage("No matching DWARF binary found for process: \(frame.binaryImage.name)")
                hasFailed = true
                continue
            }

            if !symbolicateFrame(frame: frame, dsymPath: selectedBinaryPath, architecture: architecture) {
                hasFailed = true
            }
        }

        return !hasFailed
    }

    private func symbolicateFrame(frame: StackFrame, dsymPath: String, architecture: Architecture) -> Bool {
        let command = symbolicationCommand(
            dsymPath: dsymPath,
            architecture: architecture.atosString!,
            loadAddress: frame.binaryImage.loadAddress,
            address: frame.cryptedAddress
        )
        logController.addLogMessage("Running command: \(command)")

        let atosResult = command.run()

        logController.addLogMessages([
            "STDOUT:\n\(atosResult.output?.trimmed ?? "")",
            "STDERR:\n\(atosResult.error?.trimmed ?? "")"
        ])

        if let symbolicatedAddress = atosResult.output?.trimmed, !symbolicatedAddress.isEmpty {
            frame.symbolicatedAddress = symbolicatedAddress
            return true
        } else {
            logController.addLogMessage("Symbolication failed for address: \(frame.cryptedAddress)")
            return false
        }
    }

    private func symbolicationCommand(
        dsymPath: String,
        architecture: String,
        loadAddress: String,
        address: String
    ) -> String {
        return "xcrun atos -o \"\(dsymPath)\" -arch \(architecture) -l \(loadAddress) \(address)"
    }

    private mutating func updateSymbolicatedContent() {
        let mutableAttributedString = NSMutableAttributedString(string: reportFile.content)
        var offset = 0

        reportFile.processes.forEach { process in
            process.stackFrames.forEach { frame in
                if let symbolicatedAddress = frame.symbolicatedAddress,
                   let range = reportFile.content.range(of: frame.originalLine) {
                    let symbolicatedLine = frame.symbolicateLine(with: symbolicatedAddress)
                    let nsRange = NSRange(range, in: reportFile.content)
                    let adjustedRange = NSRange(location: nsRange.location + offset, length: nsRange.length)

                    mutableAttributedString.replaceCharacters(in: adjustedRange, with: symbolicatedLine)
                    offset += symbolicatedLine.length - nsRange.length
                }
            }
        }

        symbolicatedContent = mutableAttributedString
    }
}
