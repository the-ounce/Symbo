//
//  TextWindowController.swift
//  MacSymbolicator
//

import Cocoa

class TextWindowController: NSObject {
    private let window = CenteredWindow(width: 1100, height: 800)
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    private let savePanel = NSSavePanel()

    var defaultSaveURL: URL? {
        didSet {
            let saveButton = window.toolbar?.items.compactMap { $0.view as? NSButton }.first
            saveButton?.title = defaultSaveURL == nil ? "Save…" : "Save"
        }
    }

    var attributedText: NSAttributedString {
        get {
            return textView.attributedString()
        }
        set {
            textView.textStorage?.setAttributedString(newValue)
            applyDefaultAttributesToText()
        }
    }

    let clearable: Bool

    init(title: String, clearable: Bool) {
        self.clearable = clearable

        super.init()

        window.styleMask = [.borderless, .titled, .closable, .resizable]
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.title = title
        window.minSize = NSSize(width: 400, height: 400)
        window.backgroundColor = .black

        setupTextView()
        setupScrollView()
        setupToolbar()
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "TextWindowControllerToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }

    private func setupTextView() {
        textView.autoresizingMask = .width
        textView.isEditable = false
    }

    private func setupScrollView() {
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = window.contentView!
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func applyDefaultAttributesToText() {
        guard let textStorage = textView.textStorage else { return }

        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Menlo", size: NSFont.smallSystemFontSize) ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]

        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.enumerateAttributes(in: fullRange, options: []) { (attributes, range, _) in
            var newAttributes = [NSAttributedString.Key: Any]()

            for (key, value) in defaultAttributes {
                if attributes[key] == nil {
                    newAttributes[key] = value
                }
            }

            if !newAttributes.isEmpty {
                textStorage.addAttributes(newAttributes, range: range)
            }
        }
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
    }

    @objc func save() {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["crash"]
        savePanel.canCreateDirectories = true

        if let defaultSaveURL = defaultSaveURL {
            savePanel.directoryURL = defaultSaveURL.deletingLastPathComponent()
            savePanel.nameFieldStringValue = defaultSaveURL.lastPathComponent
        }

        savePanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try self.attributedText.string.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    @objc func clear() {
        attributedText = NSAttributedString()
    }
}

extension TextWindowController: NSToolbarDelegate {
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier.rawValue {
        case NSToolbarItem.Identifier.save.rawValue:
            let saveToolbarItem = NSToolbarItem(itemIdentifier: .save)
            saveToolbarItem.label = "Save"
            saveToolbarItem.paletteLabel = "Save"
            saveToolbarItem.target = self
            saveToolbarItem.action = #selector(save)

            let saveButton = NSButton()
            saveButton.bezelStyle = .texturedRounded
            saveButton.title = defaultSaveURL == nil ? "Save…" : "Save"
            saveButton.target = self
            saveButton.action = #selector(save)
            saveToolbarItem.view = saveButton

            return saveToolbarItem
        case NSToolbarItem.Identifier.clear.rawValue:
            let clearToolbarItem = NSToolbarItem(itemIdentifier: .clear)
            clearToolbarItem.label = "Clear"
            clearToolbarItem.paletteLabel = "Clear"
            clearToolbarItem.target = self
            clearToolbarItem.action = #selector(clear)

            let clearButton = NSButton()
            clearButton.bezelStyle = .texturedRounded
            clearButton.title = "Clear"
            clearButton.target = self
            clearButton.action = #selector(clear)
            clearToolbarItem.view = clearButton

            return clearToolbarItem
        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if clearable {
            return [.flexibleSpace, .clear, .save]
        } else {
            return [.flexibleSpace, .save]
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if clearable {
            return [.flexibleSpace, .clear, .save]
        } else {
            return [.flexibleSpace, .save]
        }
    }
}

extension NSToolbarItem.Identifier {
    static var clear = NSToolbarItem.Identifier(rawValue: "Clear")
    static var save = NSToolbarItem.Identifier(rawValue: "Save")
}
