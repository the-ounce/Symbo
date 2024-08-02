//
//  MainController.swift
//  MacSymbolicator
//

import Cocoa

class MainController {
    private let mainWindow = CenteredWindow(width: 800, height: 400)
    private let textWindowController = TextWindowController(title: "Symbolicated Content", clearable: false)

    private var updateButton: NSButton?
    private var availableUpdateURL: URL?

    private let titlebarView = NSView()
    private let dropZonesContainerView = NSView()
    private let statusView = NSView()
    private let statusTextField = NSTextField()

    private let symbolicateButton = NSButton()
    private let viewLogsButton = NSButton()

    private var reportFileDropZone: DropZone {
        return inputCoordinator.reportFileDropZone
    }

    private var dsymFilesDropZone: DropZone {
        return inputCoordinator.dsymFilesDropZone
    }

    private var isSymbolicating: Bool = false {
        didSet {
            updateSymbolicateButtonState()
            symbolicateButton.title = isSymbolicating ? "Symbolicating…" : "Symbolicate"
        }
    }

    private var isReportFileAvailable: Bool = false {
        didSet {
            updateSymbolicateButtonState()
            updateDropZonesLayout()
        }
    }

    private var isDSYMAvailable: Bool = false {
        didSet {
            updateSymbolicateButtonState()
        }
    }

    private func updateSymbolicateButtonState() {
        symbolicateButton.isEnabled = isReportFileAvailable && isDSYMAvailable && !isSymbolicating
    }

    private lazy var logController: ViewableLogController = DefaultViewableLogController()
    private lazy var inputCoordinator = InputCoordinator(logController: logController)

    init() {
        logController.delegate = self
        inputCoordinator.delegate = self

        let reportFileDropZone = inputCoordinator.reportFileDropZone
        let dsymFilesDropZone = inputCoordinator.dsymFilesDropZone

        let titleLabel = NSTextField(labelWithString: "Symbo")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        titlebarView.translatesAutoresizingMaskIntoConstraints = false
        titlebarView.wantsLayer = true
        titlebarView.addSubview(titleLabel)

        statusTextField.drawsBackground = false
        statusTextField.isBezeled = false
        statusTextField.isEditable = false
        statusTextField.isSelectable = false

        symbolicateButton.title = "Symbolicate"
        symbolicateButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        symbolicateButton.bezelStyle = .regularSquare
        symbolicateButton.focusRingType = .none
        symbolicateButton.setButtonType(.momentaryPushIn)
        symbolicateButton.target = self
        symbolicateButton.action = #selector(MainController.symbolicate)
        symbolicateButton.isEnabled = false

        viewLogsButton.title = "View Logs…"
        viewLogsButton.bezelStyle = .regularSquare
        viewLogsButton.focusRingType = .none
        viewLogsButton.target = logController
        viewLogsButton.action = #selector(ViewableLogController.viewLogs)
        viewLogsButton.isHidden = true

        let contentView = mainWindow.contentView!
        contentView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        contentView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        contentView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        contentView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        contentView.addSubview(titlebarView)
        contentView.addSubview(dropZonesContainerView)
        contentView.addSubview(statusView)

        titlebarView.addSubview(titleLabel)
        dropZonesContainerView.addSubview(reportFileDropZone)
        dropZonesContainerView.addSubview(dsymFilesDropZone)
        statusView.addSubview(statusTextField)
        statusView.addSubview(symbolicateButton)
        statusView.addSubview(viewLogsButton)

        // Disable autoresizing mask translation for all views
        [contentView, titlebarView, dropZonesContainerView, statusView, titleLabel,
         reportFileDropZone, dsymFilesDropZone, statusTextField, symbolicateButton, viewLogsButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Content View
            contentView.heightAnchor.constraint(equalToConstant: 400),
            contentView.widthAnchor.constraint(equalToConstant: 800),

            // Titlebar View
            titlebarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            titlebarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titlebarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titlebarView.heightAnchor.constraint(equalToConstant: 30),

            // Title Label
            titleLabel.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),

            // Drop Zones Container View
            dropZonesContainerView.topAnchor.constraint(equalTo: titlebarView.bottomAnchor),
            dropZonesContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            dropZonesContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            dropZonesContainerView.bottomAnchor.constraint(equalTo: statusView.topAnchor),

            // Report File Drop Zone
            reportFileDropZone.topAnchor.constraint(equalTo: dropZonesContainerView.topAnchor),
            reportFileDropZone.leadingAnchor.constraint(equalTo: dropZonesContainerView.leadingAnchor),
            reportFileDropZone.bottomAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),

            // DSYM Files Drop Zone
            dsymFilesDropZone.topAnchor.constraint(equalTo: dropZonesContainerView.topAnchor),
            dsymFilesDropZone.trailingAnchor.constraint(equalTo: dropZonesContainerView.trailingAnchor),
            dsymFilesDropZone.bottomAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),

            // Status View
            statusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 50),

            // Status Text Field
            statusTextField.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 20),
            statusTextField.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusTextField.widthAnchor.constraint(equalToConstant: 120),

            // Symbolicate Button
            symbolicateButton.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            symbolicateButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            symbolicateButton.widthAnchor.constraint(equalToConstant: 120),
            symbolicateButton.heightAnchor.constraint(equalToConstant: 30),

            // View Logs Button
            viewLogsButton.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -20),
            viewLogsButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            viewLogsButton.widthAnchor.constraint(equalToConstant: 120),
            viewLogsButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        updateDropZonesLayout()
        mainWindow.makeKeyAndOrderFront(nil)
    }

    private func updateDropZonesLayout() {
        // Remove any existing constraints for the drop zones
        dropZonesContainerView.constraints.forEach { constraint in
            if constraint.firstItem === reportFileDropZone || constraint.secondItem === reportFileDropZone ||
                constraint.firstItem === dsymFilesDropZone || constraint.secondItem === dsymFilesDropZone {
                dropZonesContainerView.removeConstraint(constraint)
            }
        }

        // Common constraints for both cases
        NSLayoutConstraint.activate([
            reportFileDropZone.topAnchor.constraint(equalTo: dropZonesContainerView.topAnchor),
            reportFileDropZone.bottomAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),
            reportFileDropZone.leadingAnchor.constraint(equalTo: dropZonesContainerView.leadingAnchor)
        ])

        if isReportFileAvailable {
            NSLayoutConstraint.activate([
                dsymFilesDropZone.topAnchor.constraint(equalTo: dropZonesContainerView.topAnchor),
                dsymFilesDropZone.bottomAnchor.constraint(equalTo: dropZonesContainerView.bottomAnchor),
                dsymFilesDropZone.trailingAnchor.constraint(equalTo: dropZonesContainerView.trailingAnchor),
                dsymFilesDropZone.leadingAnchor.constraint(equalTo: reportFileDropZone.trailingAnchor, constant: 5),
                reportFileDropZone.widthAnchor.constraint(equalTo: dsymFilesDropZone.widthAnchor)
            ])
            dsymFilesDropZone.isHidden = false
        } else {
            NSLayoutConstraint.activate([
                reportFileDropZone.trailingAnchor.constraint(equalTo: dropZonesContainerView.trailingAnchor)
            ])
            dsymFilesDropZone.isHidden = true
        }
    }

    deinit {
        logController.delegate = nil
        inputCoordinator.delegate = nil
    }

    @objc func symbolicate() {
        guard !isSymbolicating else { return }

        guard let reportFile = inputCoordinator.reportFile else {
            inputCoordinator.reportFileDropZone.flash()
            return
        }

        guard !inputCoordinator.dsymFiles.isEmpty else {
            inputCoordinator.dsymFilesDropZone.flash()
            return
        }

        logController.resetLogs()

        isSymbolicating = true

        let dsymFiles = inputCoordinator.dsymFiles
        var symbolicator = Symbolicator(
            reportFile: reportFile,
            dsymFiles: dsymFiles,
            logController: logController
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let success = symbolicator.symbolicate()

            DispatchQueue.main.async {
                if success {
                    self.textWindowController.attributedText = symbolicator.symbolicatedContent ??
                        NSAttributedString(string: "")
                    self.textWindowController.defaultSaveURL = reportFile.symbolicatedContentSaveURL
                    self.textWindowController.showWindow()
                } else {
                    let alert = NSAlert()
                    alert.informativeText = "Symbolication failed. See logs for more info."
                    alert.alertStyle = .critical

                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "View Logs…")

                    if alert.runModal() == .alertSecondButtonReturn {
                        self.logController.viewLogs()
                    }
                }

                self.isSymbolicating = false
            }
        }
    }

    func openFile(_ path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        return inputCoordinator.acceptReportFile(url: fileURL) || inputCoordinator.acceptDSYMFile(url: fileURL)
    }

    func suggestUpdate(version: String, url: URL) {
        availableUpdateURL = url

        let updateButton = self.updateButton ?? NSButton()
        updateButton.title = "Update available: \(version)"
        updateButton.controlSize = .small
        updateButton.bezelStyle = .roundRect
        updateButton.target = self
        updateButton.action = #selector(self.tappedUpdateButton(_:))

        guard let frameView = mainWindow.contentView?.superview else {
            return
        }

        frameView.addSubview(updateButton)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            updateButton.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -6),
            updateButton.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 6)
        ])
    }

    @objc
    private func tappedUpdateButton(_ sender: AnyObject?) {
        guard let availableUpdateURL = availableUpdateURL else { return }
        NSWorkspace.shared.open(availableUpdateURL)
    }
}

extension MainController: LogControllerDelegate {
    func logController(_ controller: LogController, logsUpdated logMessages: [String]) {
        DispatchQueue.main.async {
            self.viewLogsButton.isHidden = logMessages.isEmpty
        }
    }
}

extension MainController: InputCoordinatorDelegate {
    func inputCoordinator(_ coordinator: InputCoordinator, didReceiveReportFile: Bool) {
        isReportFileAvailable = didReceiveReportFile
    }

    func inputCoordinator(_ coordinator: InputCoordinator, didChangeDSYMAvailability isAvailable: Bool) {
        isDSYMAvailable = isAvailable
    }
}
