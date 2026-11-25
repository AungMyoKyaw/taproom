import AppKit
import SwiftUI

struct LiveLogTextView: NSViewRepresentable {
    let lines: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator

        if lines.isEmpty {
            if coordinator.renderedLineCount > 0 {
                textView.string = ""
                coordinator.renderedLineCount = 0
                coordinator.firstLine = nil
            }
            return
        }

        let nearBottom = scrollView.documentVisibleRect.maxY >= textView.bounds.height - 24
        let isSameStream = coordinator.firstLine == lines.first && lines.count >= coordinator.renderedLineCount

        if !isSameStream {
            let clean = lines.map(Self.stripANSI).joined(separator: "\n")
            textView.string = clean
            coordinator.firstLine = lines.first
            coordinator.renderedLineCount = lines.count
            textView.scrollToEndOfDocument(nil)
            return
        }

        guard lines.count > coordinator.renderedLineCount else { return }
        let newSlice = lines[coordinator.renderedLineCount...].map(Self.stripANSI)
        let prefix = coordinator.renderedLineCount > 0 ? "\n" : ""
        let chunk = prefix + newSlice.joined(separator: "\n")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        textView.textStorage?.append(NSAttributedString(string: chunk, attributes: attrs))
        coordinator.renderedLineCount = lines.count

        if nearBottom {
            textView.scrollToEndOfDocument(nil)
        }
    }

    final class Coordinator {
        var firstLine: String?
        var renderedLineCount: Int = 0
    }

    private static func stripANSI(_ line: String) -> String {
        line.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
    }
}
