//
//  Symbolicator.swift
//  MacSymbolicator
//

import Cocoa

struct Symbolicator {
    let reportFile: ReportFile
    let dsymFiles: [DSYMFile]

    var symbolicatedContent: String?
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
        logController.addLogMessage("""
        —————————————————————————————————————————————————
        * Symbolicating process \(process.name ?? "<null>")
        """)

        guard let architecture = process.architecture else {
            logController.addLogMessage("Could not detect process architecture.")
            return false
        }

        if !process.stackFrames.isEmpty && process.binaryImages.isEmpty {
            logController.addLogMessage("""
            Could not detect application binary images for reported process \(process.name ?? "<null>").\
            Application might have crashed during launch.
            """)
            return false
        }

        guard !process.stackFrames.isEmpty else {
            logController.addLogMessage("""
            Did not find anything to symbolicate for process \(process.name ?? "<null>").
            """)
            return true
        }

        var dsymsByUUID = [BinaryUUID: DSYMFile]()
        var dsymsByLoadAddress = [String: DSYMFile]()

        // First, create a mapping of UUIDs to dSYM files
        for dsymFile in dsymFiles {
            for (uuid, _) in dsymFile.uuids {
                dsymsByUUID[uuid] = dsymFile
            }
        }

        // Then, match binary images to dSYM files
        for binaryImage in process.binaryImages {
            if let dsymFile = dsymsByUUID[binaryImage.uuid] {
                dsymsByLoadAddress[binaryImage.loadAddress] = dsymFile
                print(dsymFiles)
            }
        }

        // Log any missing dSYM files
        let missingDSYMs = process.binaryImages.filter { dsymsByLoadAddress[$0.loadAddress] == nil }
        for missingBinary in missingDSYMs {
            logController.addLogMessage("Missing dSYM for binary: \(missingBinary.name) (UUID: \(missingBinary.uuid.pretty))")
        }

        guard !dsymsByLoadAddress.isEmpty else {
            logController.addLogMessage("No matching dSYMs found for symbolicating \(process.name ?? "<null>")")
            return true
        }

        var hasFailed = false

        process.stackFrames.forEach { frame in
            guard let dsymFile = dsymsByLoadAddress[frame.binaryImage.loadAddress] else { return }

            let command = symbolicationCommand(
                dsymPath: dsymFile.binaryPath,
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
            } else {
                logController.addLogMessage("Symbolication failed for address: \(frame.cryptedAddress)")
                hasFailed = true
            }
        }

        return !hasFailed
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
        var updatedContent = reportFile.content
        reportFile.processes.forEach { process in
            process.stackFrames.forEach { frame in
                if let symbolicatedAddress = frame.symbolicatedAddress {
                    let symbolicatedLine = frame.symbolicateLine(with: symbolicatedAddress)
                    updatedContent = updatedContent.replacingOccurrences(of: frame.originalLine, with: symbolicatedLine)
                }
            }
        }
        symbolicatedContent = updatedContent
    }
}
