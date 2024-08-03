//
//  TextInputView.swift
//  Symbo
//
//  Created by Mykyta Havrylenko on 03.08.2024.
//

import AppKit

class TextInputView: NSView {
    private let scrollView = NSScrollView()
    let textView = NSTextView()
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)

    var onClearButtonClicked: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        setupScrollView()
        setupTextView()
        setupClearButton()
    }

    private func setupScrollView() {
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    private func setupTextView() {
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self

        scrollView.documentView = textView
    }

    private func setupClearButton() {
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .regular
        clearButton.font = NSFont.systemFont(ofSize: 12)
        clearButton.target = self
        clearButton.action = #selector(clearButtonClicked)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])

        updateClearButtonVisibility()
    }

    @objc private func clearButtonClicked() {
        setText("")
        onClearButtonClicked?()
    }

    func updateClearButtonVisibility() {
        clearButton.isHidden = textView.string.isEmpty
    }

    func getText() -> String {
        return textView.string
    }

    func setText(_ text: String) {
        textView.string = text
        updateClearButtonVisibility()
    }
}

extension TextInputView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateClearButtonVisibility()
    }
}
