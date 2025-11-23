import AppKit

public class LiquidGlassMenuItemView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let highlightView: NSView  // Changed from NSVisualEffectView to properly show accent color
    private let dotView: DotView?
    private let titleLabel: NSTextField
    private let accessoryLabel: NSTextField?
    private let loadingIndicator: NSProgressIndicator
    private let action: Selector?
    private weak var target: AnyObject?
    private var clickGestureRecognizer: NSClickGestureRecognizer!
    private let isEnabled: Bool
    private var trackingArea: NSTrackingArea?
    private var isProcessing: Bool = false

    private class DotView: NSView {
        private let dotLayer = CALayer()

        init(color: NSColor) {
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            dotLayer.backgroundColor = color.cgColor
            dotLayer.cornerRadius = 5.0
            dotLayer.masksToBounds = true
            layer?.addSublayer(dotLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            dotLayer.frame = bounds
            dotLayer.cornerRadius = bounds.height / 2
        }

        override var intrinsicContentSize: NSSize {
            return NSSize(width: 10, height: 10)
        }

        func updateColor(_ color: NSColor) {
            dotLayer.backgroundColor = color.cgColor
        }
    }

    public init(title: String,
                dotColor: NSColor? = nil,
                isEnabled: Bool = true,
                action: Selector? = nil,
                target: AnyObject? = nil,
                accessoryText: String? = nil) {
        self.visualEffectView = NSVisualEffectView()
        self.highlightView = NSView()  // Changed from NSVisualEffectView
        self.isEnabled = isEnabled
        self.action = action
        self.target = target

        if let dotColor = dotColor {
            self.dotView = DotView(color: dotColor)
        } else {
            self.dotView = nil
        }

        self.titleLabel = NSTextField(labelWithString: title)
        self.accessoryLabel = accessoryText != nil ? NSTextField(labelWithString: accessoryText!) : nil

        // Setup loading indicator
        self.loadingIndicator = NSProgressIndicator()
        self.loadingIndicator.style = .spinning
        self.loadingIndicator.controlSize = .small
        self.loadingIndicator.isDisplayedWhenStopped = false

        super.init(frame: .zero)

        setupVisualEffectView()
        setupHighlightView()
        setupSubviews()
        setupGestureRecognizer()
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHighlightView() {
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        highlightView.wantsLayer = true
        highlightView.isHidden = true
        
        // Configure the layer for proper blending
        if let layer = highlightView.layer {
            // Use selectedContentBackgroundColor which is designed for menu selections
            // This automatically provides the correct accent color without vibrancy interference
            layer.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
            
            // Add a subtle corner radius to match modern macOS design
            layer.cornerRadius = 4.0
        }

        visualEffectView.addSubview(highlightView)

        NSLayoutConstraint.activate([
            highlightView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 4),
            highlightView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -4),
            highlightView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 2),
            highlightView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -2),
        ])
    }

    private func setupVisualEffectView() {
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupSubviews() {
        layer?.masksToBounds = true

        // Dot view
        if let dotView = dotView {
            dotView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.addSubview(dotView)
            NSLayoutConstraint.activate([
                dotView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
                dotView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 10),
                dotView.heightAnchor.constraint(equalToConstant: 10),
            ])
        }

        // Loading indicator (positioned where dot is)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10),
            loadingIndicator.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 14),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 14),
        ])

        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingTail
        visualEffectView.addSubview(titleLabel)

        // Accessory label
        if let accessoryLabel = accessoryLabel {
            accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
            accessoryLabel.font = NSFont.systemFont(ofSize: 12)
            accessoryLabel.isEditable = false
            accessoryLabel.isSelectable = false
            accessoryLabel.isBezeled = false
            accessoryLabel.drawsBackground = false
            accessoryLabel.lineBreakMode = .byTruncatingTail
            accessoryLabel.alignment = .right
            visualEffectView.addSubview(accessoryLabel)
        }

        // Layout constraints for title and accessory
        if let dotView = dotView {
            if let accessoryLabel = accessoryLabel {
                NSLayoutConstraint.activate([
                    titleLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 8),
                    titleLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                    accessoryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
                    accessoryLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
                    accessoryLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                    accessoryLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
                ])
            } else {
                NSLayoutConstraint.activate([
                    titleLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 8),
                    titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
                    titleLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor)
                ])
            }
        } else {
            if let accessoryLabel = accessoryLabel {
                NSLayoutConstraint.activate([
                    titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
                    titleLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                    accessoryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
                    accessoryLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
                    accessoryLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
                    accessoryLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
                ])
            } else {
                NSLayoutConstraint.activate([
                    titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
                    titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
                    titleLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor)
                ])
            }
        }
    }

    private func setupGestureRecognizer() {
        clickGestureRecognizer = NSClickGestureRecognizer(target: self, action: #selector(didClick))
        // Allow the gesture to work without closing the menu
        clickGestureRecognizer.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(clickGestureRecognizer)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        // Use .activeAlways to ensure tracking works even when menu is key window
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    public override func layout() {
        super.layout()
        // Update tracking areas whenever layout changes
        updateTrackingAreas()
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if isEnabled && !isProcessing {
            setHighlighted(true)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHighlighted(false)
    }

    public override func mouseUp(with event: NSEvent) {
        // Handle clicks within bounds
        guard isEnabled, !isProcessing, bounds.contains(convert(event.locationInWindow, from: nil)) else {
            super.mouseUp(with: event)
            return
        }

        // Perform the action
        if let action = action, let target = target {
            NSApp.sendAction(action, to: target, from: self)
        }

        // Note: Not calling super.mouseUp(with: event) prevents the menu from closing
        // This allows the user to see the loading indicator and updated state
    }

    @objc private func didClick() {
        // This is called by the gesture recognizer as a backup
        guard isEnabled, !isProcessing, let action = action, let target = target else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    public override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 26)
    }

    public func setHighlighted(_ highlighted: Bool) {
        // Show/hide the custom highlight view with system accent color
        highlightView.isHidden = !highlighted
    }

    public override func updateLayer() {
        super.updateLayer()
        updateColors()
    }

    private func updateColors() {
        let effectivelyEnabled = isEnabled && !isProcessing

        if effectivelyEnabled {
            if let dotView = dotView {
                dotView.alphaValue = 1
            }
            titleLabel.textColor = NSColor.controlTextColor
        } else {
            if let dotView = dotView {
                dotView.alphaValue = 0.4
            }
            titleLabel.textColor = NSColor.disabledControlTextColor
        }

        if let accessoryLabel = accessoryLabel {
            accessoryLabel.textColor = NSColor.secondaryLabelColor
        }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
        updateHighlightColor()
    }

    private func updateHighlightColor() {
        // Update highlight to use selectedContentBackgroundColor which matches system accent
        if let layer = highlightView.layer {
            layer.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        }
    }

    public func updateDotColor(_ color: NSColor) {
        dotView?.updateColor(color)
        // Ensure tracking areas are active after updates
        updateTrackingAreas()
    }

    public var title: String {
        return titleLabel.stringValue
    }

    // MARK: - Loading State

    public func setLoading(_ loading: Bool) {
        isProcessing = loading

        if loading {
            dotView?.isHidden = true
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
            dotView?.isHidden = false
        }

        // Update the visual state to reflect that the item is now disabled during processing
        updateColors()

        // Remove highlight if we're now processing
        if loading {
            setHighlighted(false)
        }
        
        // Force tracking areas to be reconfigured after loading state changes
        needsUpdateConstraints = true
        layoutSubtreeIfNeeded()
        updateTrackingAreas()
    }

    public var isLoading: Bool {
        return isProcessing
    }

    // MARK: - Convenience builder

    public static func menuItem(title: String,
                                dotColor: NSColor? = nil,
                                isEnabled: Bool = true,
                                action: Selector? = nil,
                                target: AnyObject? = nil,
                                accessoryText: String? = nil) -> NSMenuItem
    {
        let view = LiquidGlassMenuItemView(title: title,
                                           dotColor: dotColor,
                                           isEnabled: isEnabled,
                                           action: action,
                                           target: target,
                                           accessoryText: accessoryText)

        // Disable autoresizing mask to prevent conflicts
        view.translatesAutoresizingMaskIntoConstraints = false

        let menuItem = NSMenuItem()
        menuItem.view = view
        menuItem.isEnabled = isEnabled

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 220),
            view.heightAnchor.constraint(equalToConstant: 26)
        ])
        return menuItem
    }

    public static func separator() -> NSMenuItem {
        let separatorView = LiquidGlassSeparatorView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false

        let menuItem = NSMenuItem()
        menuItem.view = separatorView
        menuItem.isEnabled = false

        NSLayoutConstraint.activate([
            separatorView.widthAnchor.constraint(equalToConstant: 220),
            separatorView.heightAnchor.constraint(equalToConstant: 12)
        ])

        return menuItem
    }

    public static func spacer() -> NSMenuItem {
        let spacerView = LiquidGlassSpacerView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false

        let menuItem = NSMenuItem()
        menuItem.view = spacerView
        menuItem.isEnabled = false

        NSLayoutConstraint.activate([
            spacerView.widthAnchor.constraint(equalToConstant: 220),
            spacerView.heightAnchor.constraint(equalToConstant: 6)
        ])

        return menuItem
    }

    public static func loading(message: String = "Loading services...") -> NSMenuItem {
        let loadingView = LiquidGlassLoadingView(message: message)
        loadingView.translatesAutoresizingMaskIntoConstraints = false

        let menuItem = NSMenuItem()
        menuItem.view = loadingView
        menuItem.isEnabled = false

        NSLayoutConstraint.activate([
            loadingView.widthAnchor.constraint(equalToConstant: 220),
            loadingView.heightAnchor.constraint(equalToConstant: 40)
        ])

        return menuItem
    }
}

// MARK: - Liquid Glass Separator

private class LiquidGlassSeparatorView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let separatorLine: CALayer

    override init(frame frameRect: NSRect) {
        self.visualEffectView = NSVisualEffectView()
        self.separatorLine = CALayer()

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = false

        setupVisualEffectView()
        setupSeparatorLine()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisualEffectView() {
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        visualEffectView.layer?.masksToBounds = false
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupSeparatorLine() {
        separatorLine.backgroundColor = NSColor.separatorColor.cgColor
        visualEffectView.layer?.addSublayer(separatorLine)

        updateSeparatorColor()
    }

    private func updateSeparatorColor() {
        // Use the system separator color which adapts to light/dark mode
        separatorLine.backgroundColor = NSColor.separatorColor.cgColor
    }

    override func layout() {
        super.layout()

        // Position the separator line in the center
        let lineHeight: CGFloat = 1.0
        let horizontalInset: CGFloat = 12.0

        separatorLine.frame = CGRect(
            x: horizontalInset,
            y: (bounds.height - lineHeight) / 2.0,
            width: bounds.width - (horizontalInset * 2),
            height: lineHeight
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSeparatorColor()
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 12)
    }
}

// MARK: - Liquid Glass Spacer

private class LiquidGlassSpacerView: NSView {
    private let visualEffectView: NSVisualEffectView

    override init(frame frameRect: NSRect) {
        self.visualEffectView = NSVisualEffectView()

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = false

        setupVisualEffectView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisualEffectView() {
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        visualEffectView.layer?.masksToBounds = false
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 6)
    }
}

// MARK: - Liquid Glass Loading View

private class LiquidGlassLoadingView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let loadingIndicator: NSProgressIndicator
    private let messageLabel: NSTextField

    init(message: String) {
        self.visualEffectView = NSVisualEffectView()
        self.loadingIndicator = NSProgressIndicator()
        self.messageLabel = NSTextField(labelWithString: message)

        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = false

        setupVisualEffectView()
        setupLoadingIndicator()
        setupMessageLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisualEffectView() {
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        visualEffectView.layer?.masksToBounds = false
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.startAnimation(nil)
        visualEffectView.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
            loadingIndicator.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 16),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func setupMessageLabel() {
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = NSFont.systemFont(ofSize: 12)
        messageLabel.textColor = NSColor.secondaryLabelColor
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.isBezeled = false
        messageLabel.drawsBackground = false
        messageLabel.lineBreakMode = .byTruncatingTail
        visualEffectView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: loadingIndicator.trailingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor)
        ])
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 40)
    }
}

