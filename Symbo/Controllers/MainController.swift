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

    private lazy var inputCoordinator = InputCoordinator(logController: logController)

    private var isSymbolicating: Bool = false {
        didSet {
            symbolicateButton.isEnabled = !isSymbolicating
            symbolicateButton.title = isSymbolicating ? "Symbolicating…" : "Symbolicate"
        }
    }

    private let logController: ViewableLogController = DefaultViewableLogController()

    init() {
        logController.delegate = self

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

        let dropZonesStackView = NSStackView()
        dropZonesStackView.orientation = .horizontal
        dropZonesStackView.distribution = .fillEqually
        dropZonesStackView.spacing = 5
        dropZonesStackView.translatesAutoresizingMaskIntoConstraints = false

        let reportFileDropZoneContainer = NSView()
        reportFileDropZoneContainer.translatesAutoresizingMaskIntoConstraints = false
        reportFileDropZoneContainer.addSubview(reportFileDropZone)

        let dsymFilesDropZoneContainer = NSView()
        dsymFilesDropZoneContainer.translatesAutoresizingMaskIntoConstraints = false
        dsymFilesDropZoneContainer.addSubview(dsymFilesDropZone)

        dropZonesStackView.addArrangedSubview(reportFileDropZoneContainer)
        dropZonesStackView.addArrangedSubview(dsymFilesDropZoneContainer)

        contentView.addSubview(dropZonesStackView)
        contentView.addSubview(statusView)
        contentView.addSubview(titlebarView)
        statusView.addSubview(statusTextField)
        statusView.addSubview(symbolicateButton)
        statusView.addSubview(viewLogsButton)

        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusTextField.translatesAutoresizingMaskIntoConstraints = false
        symbolicateButton.translatesAutoresizingMaskIntoConstraints = false
        viewLogsButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 400),
            contentView.widthAnchor.constraint(equalToConstant: 800),

            titlebarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            titlebarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titlebarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titlebarView.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),

            dropZonesStackView.topAnchor.constraint(equalTo: titlebarView.topAnchor, constant: 25),
            dropZonesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            dropZonesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            dropZonesStackView.bottomAnchor.constraint(equalTo: statusView.topAnchor),

            reportFileDropZone.topAnchor.constraint(equalTo: reportFileDropZoneContainer.topAnchor),
            reportFileDropZone.leadingAnchor.constraint(equalTo: reportFileDropZoneContainer.leadingAnchor),
            reportFileDropZone.trailingAnchor.constraint(equalTo: reportFileDropZoneContainer.trailingAnchor),
            reportFileDropZone.bottomAnchor.constraint(equalTo: reportFileDropZoneContainer.bottomAnchor),

            dsymFilesDropZone.topAnchor.constraint(equalTo: dsymFilesDropZoneContainer.topAnchor),
            dsymFilesDropZone.leadingAnchor.constraint(equalTo: dsymFilesDropZoneContainer.leadingAnchor),
            dsymFilesDropZone.trailingAnchor.constraint(equalTo: dsymFilesDropZoneContainer.trailingAnchor),
            dsymFilesDropZone.bottomAnchor.constraint(equalTo: dsymFilesDropZoneContainer.bottomAnchor),

            statusView.topAnchor.constraint(equalTo: dropZonesStackView.bottomAnchor),
            statusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 50),

            statusTextField.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 20),
            statusTextField.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusTextField.widthAnchor.constraint(equalToConstant: 120),

            symbolicateButton.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            symbolicateButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            symbolicateButton.widthAnchor.constraint(equalToConstant: 120),
            symbolicateButton.heightAnchor.constraint(equalToConstant: 30),

            viewLogsButton.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -20),
            viewLogsButton.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            viewLogsButton.widthAnchor.constraint(equalToConstant: 120),
            viewLogsButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        mainWindow.makeKeyAndOrderFront(nil)
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
                    self.textWindowController.text = symbolicator.symbolicatedContent ?? ""
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
