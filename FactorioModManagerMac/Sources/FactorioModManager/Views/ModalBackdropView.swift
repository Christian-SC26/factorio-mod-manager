import SwiftUI
import AppKit

public struct ModalBackdropView: NSViewRepresentable {
    public var onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public func makeNSView(context: Context) -> NSView {
        let view = ModalBackdropNSView()
        view.onDismiss = onDismiss
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? ModalBackdropNSView {
            v.onDismiss = onDismiss
        }
    }
}

final class ModalBackdropNSView: NSView {
    var onDismiss: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func scrollWheel(with event: NSEvent) {
        // Intercept and swallow scroll wheel events so background content does not scroll
    }
}

@MainActor
public final class DetailScrollViewCoordinator {
    public static let shared = DetailScrollViewCoordinator()
    public weak var detailScrollView: NSScrollView?

    public func scroll(by delta: CGFloat) {
        guard let scrollView = detailScrollView else { return }
        let clipView = scrollView.contentView
        var newOrigin = clipView.bounds.origin
        let docHeight = scrollView.documentView?.frame.height ?? 0
        let clipHeight = clipView.bounds.height
        let maxOriginY = max(0, docHeight - clipHeight)
        newOrigin.y = max(0, min(maxOriginY, newOrigin.y + delta))
        clipView.scroll(to: newOrigin)
        scrollView.reflectScrolledClipView(clipView)
    }
}

public struct DetailScrollAttacher: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let sv = view.enclosingScrollView {
                DetailScrollViewCoordinator.shared.detailScrollView = sv
                view.window?.makeFirstResponder(sv.documentView ?? sv)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let sv = nsView.enclosingScrollView {
                DetailScrollViewCoordinator.shared.detailScrollView = sv
            }
        }
    }
}
