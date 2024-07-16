//
//  CenteredWindow.swift
//  MacSymbolicator
//

import Cocoa

class CenteredWindow: NSWindow {
    init(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { fatalError("No attached screen found.") }

        let screenFrame = screen.frame
        let windowSize = CGSize(width: width, height: height)
        let windowOrigin = CGPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        let windowRect = CGRect(origin: windowOrigin, size: windowSize)

        super.init(contentRect: windowRect,
                   styleMask: [.fullSizeContentView, .titled, .closable, .borderless],
                   backing: .buffered,
                   defer: false)

        // Vibrancy effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = .windowBackground
        visualEffectView.frame = contentView!.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        contentView!.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isMovableByWindowBackground = true
        isOpaque = false
    }

    override func close() {
        orderOut(self)
    }
}
