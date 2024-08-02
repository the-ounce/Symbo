//
//  InputCoordinator.swift
//  MacSymbolicator
//

import Foundation

protocol InputCoordinatorDelegate: AnyObject {
    func inputCoordinator(_ coordinator: InputCoordinator, didReceiveReportFile: Bool)
    func inputCoordinator(_ coordinator: InputCoordinator, didChangeDSYMAvailability isAvailable: Bool)
}

class InputCoordinator {
    weak var delegate: InputCoordinatorDelegate?

    let reportFileDropZone = DropZone(
        fileTypes: [".crash", ".ips", ".txt"],
        allowsMultipleFiles: false,
        text: "Select or Drop your Report",
        activatesAppAfterDrop: true
    )

    let dsymFilesDropZone = DropZone(
        fileTypes: [".dSYM"],
        allowsMultipleFiles: true,
        text: "",
        detailText: "",
        activatesAppAfterDrop: true
    )

    private(set) var reportFile: ReportFile?
    private(set) var dsymFiles: [DSYMFile] = [] {
        didSet {
            delegate?.inputCoordinator(self, didChangeDSYMAvailability: !dsymFiles.isEmpty)
        }
    }

    private var isSearchingForDSYMs = false

    private let logController: LogController

    private var expectedDSYMUUIDs: Set<String> {
        guard let reportFile = reportFile else { return Set<String>() }

        return Set<String>(reportFile.uuidsForSymbolication.map { $0.pretty })
    }

    private var foundDSYMUUIDs: Set<String> {
        let addedDSYMUUIDs = dsymFiles.flatMap { $0.uuids.keys }.map { $0.pretty }
        return expectedDSYMUUIDs.intersection(addedDSYMUUIDs)
    }

    private var remainingDSYMUUIDs: Set<String> {
        expectedDSYMUUIDs.subtracting(foundDSYMUUIDs)
    }

    init(logController: any LogController) {
        self.logController = logController
        reportFileDropZone.delegate = self
        dsymFilesDropZone.delegate = self
    }

    deinit {
        reportFileDropZone.delegate = nil
        dsymFilesDropZone.delegate = nil
    }

    func acceptReportFile(url fileURL: URL) -> Bool {
        reportFileDropZone.acceptFile(url: fileURL)
    }

    func acceptDSYMFile(url fileURL: URL) -> Bool {
        dsymFilesDropZone.acceptFile(url: fileURL)
    }

    func startSearchForDSYMs() {
        guard let reportFile = reportFile else { return }

        let remainingUUIDs = Array(remainingDSYMUUIDs)

        guard !remainingUUIDs.isEmpty else {
            updateDSYMDetailText()
            return
        }

        isSearchingForDSYMs = true
        updateDSYMDetailText()

        // Trigger system alerts for folder access before starting the search
        FolderAccessTrigger.triggerAccessAlerts { [weak self] in
            self?.performDSYMSearch(forUUIDs: remainingUUIDs, reportFile: reportFile)
        }
    }

    private func performDSYMSearch(forUUIDs uuids: [String], reportFile: ReportFile) {
        DSYMSearch.search(
            forUUIDs: uuids,
            reportFileDirectory: reportFile.path.deletingLastPathComponent().path,
            logHandler: logController.addLogMessage,
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.updateSearchProgress(progress)
                }
            },
            callback: { [weak self] _, results in
                DispatchQueue.main.async {
                    results?.forEach { dsymResult in
                        let dsymURL = URL(fileURLWithPath: dsymResult.path)
                        self?.dsymFilesDropZone.acceptFile(url: dsymURL)
                    }

                    self?.isSearchingForDSYMs = false
                    self?.updateDSYMDetailText()
                }
            }
        )
    }

    func updateSearchProgress(_ progress: Float) {
        // Update UI to show search progress
        // For example, update a progress bar or show percentage in the detail text
        let percentage = Int(progress * 100)
        dsymFilesDropZone.detailText = "Searching... \(percentage)%"
    }

    func retryDSYMSearch() {
        guard let reportFile = reportFile else { return }

        let remainingUUIDs = Array(remainingDSYMUUIDs)

        guard !remainingUUIDs.isEmpty else {
            updateDSYMDetailText()
            return
        }

        isSearchingForDSYMs = true
        updateDSYMDetailText()

        DSYMSearch.search(
            forUUIDs: remainingUUIDs,
            reportFileDirectory: reportFile.path.deletingLastPathComponent().path,
            logHandler: logController.addLogMessage,
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.updateSearchProgress(progress)
                }
            },
            callback: { [weak self] _, results in
                DispatchQueue.main.async {
                    results?.forEach { dsymResult in
                        let dsymURL = URL(fileURLWithPath: dsymResult.path)
                        self?.dsymFilesDropZone.acceptFile(url: dsymURL)
                    }

                    self?.isSearchingForDSYMs = false
                    self?.updateDSYMDetailText()
                }
            }
        )
    }

    func updateCrashDetailText() {
        guard reportFile != nil else {
            // Is it nil because we couldn't initialize the reportFile or because no files have been dropped in?
            if reportFileDropZone.files.isEmpty {
                reportFileDropZone.detailText = ""
            } else {
                reportFileDropZone.detailText = "Unexpected format"
            }

            return
        }

        let expectedCount = expectedDSYMUUIDs.count
        switch expectedCount {
        case 0:
            reportFileDropZone.detailText = "(Symbolication not needed)"
        case 1:
            reportFileDropZone.detailText = "(1 dSYM needed)"
        default:
            reportFileDropZone.detailText = "(\(expectedCount) dSYMs needed)"
        }
    }

    func updateDSYMDetailText() {
        guard reportFile != nil else {
            dsymFilesDropZone.detailText = "(if not found automatically)"
            return
        }

        guard !expectedDSYMUUIDs.isEmpty else {
            dsymFilesDropZone.detailText = ""
            return
        }

        let prefix = isSearchingForDSYMs ? "Searching…" : "Found"
        let count = "\(foundDSYMUUIDs.count)/\(expectedDSYMUUIDs.count)"

        dsymFilesDropZone.detailText = "\(prefix) \(count)"
    }
}

// MARK: - DropZoneDelegate

extension InputCoordinator: DropZoneDelegate {
    func receivedFiles(dropZone: DropZone, fileURLs: [URL]) -> [URL] {
        defer {
            // Delay updating the UI until this method has returned and the drop zone's files list is updated
            if dropZone == reportFileDropZone {
                DispatchQueue.main.async(execute: self.updateCrashDetailText)
            } else if dropZone == dsymFilesDropZone {
                DispatchQueue.main.async(execute: self.updateDSYMDetailText)
            }
        }

        if dropZone == reportFileDropZone, let fileURL = fileURLs.last {
            logController.resetLogs()

            reportFile = nil

            do {
                reportFile = try ReportFile(path: fileURL)
            } catch {
                logController.addLogMessage("Error loading report file: \(error)")
            }

            if reportFile != nil {
                startSearchForDSYMs()
            }

            delegate?.inputCoordinator(self, didReceiveReportFile: reportFile != nil)

            return fileURLs
        } else if dropZone == dsymFilesDropZone {
            let dsymFiles = fileURLs.flatMap { DSYMFile.dsymFiles(from: $0) }
            self.dsymFiles.append(contentsOf: dsymFiles)

            return dsymFiles.map { $0.path }
        }

        return []
    }
}
