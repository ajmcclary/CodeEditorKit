// MARK: - AnnotationView Cross-Platform Implementation
//
// This file provides a unified AnnotationView implementation that works across
// both iOS and macOS platforms, eliminating code duplication.

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - AnnotationView Protocol

/// Protocol defining the common interface for annotation view functionality
@MainActor
public protocol AnnotationViewProtocol: AnyObject {
    var annotation: LineAnnotation { get }

    func showPopup(detachable: Bool)
    func hidePopup()
}

// MARK: - Unified AnnotationView Implementation

/// Cross-platform view for displaying annotation badges with hover/tap popups
@MainActor
public class AnnotationView: PlatformView, AnnotationViewProtocol {
    // MARK: - Properties

    public let annotation: LineAnnotation

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived badge color. Mirrors `annotationKind.color(in:)` for the
    /// applied theme; falls back to the system blue when no theme has been
    /// applied yet (matches the historical default).
    public private(set) var themedBadgeColor: PlatformColor = PlatformColors.systemBlue

    #if canImport(AppKit)
    private var trackingArea: NSTrackingArea?
    private var nsPopover: NSPopover?
    #else
    private var popoverController: UIViewController?
    private var overlayView: UIView?
    #endif

    // MARK: - Initialization

    public init(annotation: LineAnnotation, frame: CGRect) {
        self.annotation = annotation
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setup() {
        setupAppearance()
        setupIcon()
        setupInteraction()
        setupAccessibility()
    }

    private func setupAppearance() {
        // Create circular badge
        #if canImport(AppKit)
        wantsLayer = true
        layer?.cornerRadius = bounds.width / 2
        layer?.backgroundColor = annotationColor.cgColor
        #else
        layer.cornerRadius = bounds.width / 2
        backgroundColor = annotationColor
        #endif
    }

    private func setupIcon() {
        let iconView = createIconView()
        addSubview(iconView)
    }

    private func createIconView() -> PlatformImageView {
        let iconView = PlatformImageView(frame: bounds.insetBy(dx: 4, dy: 4))

        #if canImport(AppKit)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: annotationType)
        iconView.contentTintColor = PlatformColors.white
        iconView.imageScaling = .scaleProportionallyUpOrDown
        #else
        iconView.image = UIImage(systemName: iconName)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = PlatformColors.white
        #endif

        return iconView
    }

    private func setupInteraction() {
        #if canImport(AppKit)
        // Set up cursor
        addCursorRect(bounds, cursor: .pointingHand)
        #else
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        // Add long press gesture for more details
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)

        // Make accessible
        isAccessibilityElement = true
        accessibilityLabel = "\(annotationType): \(annotationMessage)"
        accessibilityTraits = .button
        #endif
    }

    // MARK: - Annotation Properties

    private var annotationKind: AnnotationKind {
        if let messageAnnotation = annotation as? MessageLineAnnotation {
            return AnnotationKind(from: messageAnnotation.kind)
        }
        return AnnotationKind.infer(from: annotationMessage)
    }

    private var annotationType: String {
        annotationKind.rawValue
    }

    private var annotationMessage: String {
        if let messageAnnotation = annotation as? MessageLineAnnotation {
            return String(messageAnnotation.message.characters)
        }
        return "Annotation"
    }

    private var annotationColor: PlatformColor {
        if let theme = appliedTheme {
            return annotationKind.color(in: theme)
        }
        return themedBadgeColor
    }

    /// Apply a theme to the annotation badge. Equality-gated; refreshes the
    /// badge fill color based on the kind and the theme's status palette.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedBadgeColor = annotationKind.color(in: theme)
        #if canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = themedBadgeColor.cgColor
        #else
        backgroundColor = themedBadgeColor
        #endif
    }

    private var iconName: String {
        annotationKind.iconName
    }

    // MARK: - Popup Management

    public func showPopup(detachable: Bool = false) {
        #if canImport(AppKit)
        showPopupMacOS(detachable: detachable)
        #else
        showPopupIOS(detachable: detachable)
        #endif
    }

    public func hidePopup() {
        #if canImport(AppKit)
        nsPopover?.close()
        nsPopover = nil
        #else
        popoverController?.dismiss(animated: true)
        popoverController = nil
        overlayView?.removeFromSuperview()
        overlayView = nil
        #endif
    }

    // MARK: - Platform-Specific Popup Implementation

    #if canImport(AppKit)
    private func showPopupMacOS(detachable: Bool) {
        guard nsPopover == nil else { return }

        let popover = NSPopover()
        popover.behavior = detachable ? .semitransient : .transient
        popover.animates = true

        // Create content view
        let contentView = createPopupContentViewMacOS()

        // Create view controller
        let contentVC = NSViewController()
        contentVC.view = contentView

        popover.contentViewController = contentVC
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)

        self.nsPopover = popover
    }

    private func createPopupContentViewMacOS() -> NSView {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))

        // Create a styled container
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.backgroundColor = PlatformColors.controlBackground.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Type label
        let typeLabel = NSTextField(labelWithString: annotationType + ":")
        typeLabel.font = PlatformFont.systemFont(ofSize: 11, weight: .semibold)
        typeLabel.textColor = annotationColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Message label
        let messageLabel = NSTextField(labelWithString: annotationMessage)
        messageLabel.font = PlatformFont.systemFont(ofSize: 11)
        messageLabel.textColor = PlatformColors.label
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(typeLabel)
        containerView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 8
            ),
            containerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -8
            ),
            containerView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 8
            ),
            containerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -8
            ),

            typeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            typeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),

            messageLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])

        return contentView
    }
    #endif

    #if canImport(UIKit)
    private func showPopupIOS(detachable: Bool) {
        guard let window = self.window,
              let rootViewController = window.rootViewController else { return }

        // Dismiss existing popover if any
        hidePopup()

        // Create content view controller
        let contentVC = UIViewController()
        contentVC.preferredContentSize = CGSize(width: 300, height: 80)

        // Create content view
        let contentView = createPopupContentViewIOS(detachable: detachable)
        contentVC.view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor, constant: 8),
            contentView.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor, constant: -8),
            contentView.topAnchor.constraint(equalTo: contentVC.view.topAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor, constant: -8)
        ])

        // Present as popover on iPad or modal on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad || detachable {
            contentVC.modalPresentationStyle = .popover

            if let popover = contentVC.popoverPresentationController {
                popover.sourceView = self
                popover.sourceRect = bounds
                popover.permittedArrowDirections = [.up, .down, .left, .right]
                popover.backgroundColor = PlatformColors.secondarySystemBackground
            }

            rootViewController.present(contentVC, animated: true)
            self.popoverController = contentVC
        } else {
            // On iPhone, show as a temporary overlay
            showTemporaryOverlay(contentView: contentView, in: window)
        }
    }

    private func createPopupContentViewIOS(detachable: Bool) -> UIView {
        let contentView = UIView()
        contentView.backgroundColor = PlatformColors.secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Type label
        let typeLabel = UILabel()
        typeLabel.text = annotationType + ":"
        typeLabel.font = PlatformFont.systemFont(ofSize: 13, weight: .semibold)
        typeLabel.textColor = annotationColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Message label
        let messageLabel = UILabel()
        messageLabel.text = annotationMessage
        messageLabel.font = PlatformFont.systemFont(ofSize: 13)
        messageLabel.textColor = PlatformColors.label
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Stack view for labels
        let stackView = UIStackView(arrangedSubviews: [typeLabel, messageLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .top
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: detachable ? -40 : -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])

        // Close button for detachable popover
        if detachable {
            let closeButton = UIButton(type: .close)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.addTarget(self, action: #selector(closePopover), for: .touchUpInside)
            contentView.addSubview(closeButton)

            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }

        return contentView
    }

    private func showTemporaryOverlay(contentView: UIView, in window: UIWindow) {
        // Convert position to window coordinates
        let annotationFrame = convert(bounds, to: window)

        // Position the overlay above or below the annotation
        let overlayY = annotationFrame.maxY + 8
        let overlayFrame = CGRect(
            x: max(8, annotationFrame.midX - 150),
            y: overlayY,
            width: 300,
            height: 80
        )

        contentView.frame = overlayFrame
        contentView.alpha = 0
        window.addSubview(contentView)

        // Store reference
        self.overlayView = contentView

        // Animate in
        UIView.animate(withDuration: 0.3) {
            contentView.alpha = 1
        }

        // Auto-dismiss after delay
        Task { @MainActor [weak self, weak contentView] in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                guard self?.overlayView === contentView else { return }
            } catch {
                // Sleep was cancelled, ignore
                return
            }

            UIView.animate(
                withDuration: 0.3,
                animations: {
                    contentView?.alpha = 0
                },
                completion: { _ in
                    contentView?.removeFromSuperview()
                    if self?.overlayView === contentView {
                        self?.overlayView = nil
                    }
                }
            )
        }
    }

    @objc private func handleTap() {
        showPopup()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        showPopup(detachable: true)
    }

    @objc private func closePopover() {
        hidePopup()
    }
    #endif

    // MARK: - Mouse/Touch Tracking

    #if canImport(AppKit)
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking area
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }

        // Add new tracking area
        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        self.trackingArea = newTrackingArea
    }

    override public func mouseEntered(with _: NSEvent) {
        showPopup()
    }

    override public func mouseExited(with _: NSEvent) {
        // Delay hiding to prevent flicker
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                guard let self,
                      let popover = self.nsPopover,
                      popover.isShown else {
                    self?.hidePopup()
                    return
                }

                // Check if mouse is still over the popover
                if let popoverWindow = popover.contentViewController?.view.window {
                    let mouseLocation = NSEvent.mouseLocation
                    let popoverScreenFrame = popoverWindow.frame

                    if !popoverScreenFrame.contains(mouseLocation) {
                        self.hidePopup()
                    }
                }
            } catch {
                // Sleep was cancelled, hide popup immediately
                self?.hidePopup()
                return
            }
        }
    }

    override public func mouseDown(with _: NSEvent) {
        // Toggle popover on click
        if nsPopover?.isShown == true {
            hidePopup()
        } else {
            showPopup(detachable: true)
        }
    }
    #endif

    // MARK: - Accessibility

    private func setupAccessibility() {
        #if canImport(UIKit)
        setupAccessibilityUIKit()
        #elseif canImport(AppKit)
        setupAccessibilityAppKit()
        #endif
    }

    #if canImport(UIKit)
    private func setupAccessibilityUIKit() {
        isAccessibilityElement = true
        accessibilityTraits = [.button, .staticText]

        // Set accessibility label based on annotation type and message
        let annotationType = annotationKind.rawValue
        let message = annotationMessage
        accessibilityLabel = "\(annotationType): \(message)"

        // Add hint to indicate interaction is available
        accessibilityHint = "Double tap to show full message"

        // Add custom actions
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: "Show details",
                target: self,
                selector: #selector(showAccessibilityDetails)
            )
        ]
    }

    @objc private func showAccessibilityDetails() {
        showPopup(detachable: true)

        // Announce that details are shown
        let announcement = "Showing details for \(annotationKind.rawValue)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    #elseif canImport(AppKit)
    private func setupAccessibilityAppKit() {
        setAccessibilityRole(.button)
        setAccessibilityRoleDescription("Code annotation")

        // Set accessibility label based on annotation type and message
        let annotationType = annotationKind.rawValue
        let message = annotationMessage
        setAccessibilityLabel("\(annotationType): \(message)")
        setAccessibilityHelp("Click to show full message")

        // Enable accessibility
        setAccessibilityEnabled(true)
    }

    override public func accessibilityPerformPress() -> Bool {
        showPopup(detachable: true)

        // Announce that details are shown
        let announcement = "Showing details for \(annotationKind.rawValue)"
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [.announcement: announcement]
        )

        return true
    }
    #endif

    // MARK: - Cleanup

    #if canImport(AppKit)
    override public func removeFromSuperview() {
        // Clean up before removal
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        hidePopup()
        discardCursorRects()
        super.removeFromSuperview()
    }
    #endif

    deinit {
        // Cleanup is handled by ARC
    }
}
