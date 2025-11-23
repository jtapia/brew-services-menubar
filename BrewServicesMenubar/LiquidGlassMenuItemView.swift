import AppKit

public class LiquidGlassMenuItemView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let dotView: DotView?
    private let titleLabel: NSTextField
    private let accessoryLabel: NSTextField?
    private let loadingIndicator: NSProgressIndicator
    private let action: Selector?
    private weak var target: AnyObject?
    private var clickGestureRecognizer: NSClickGestureRecognizer!
    private let isEnabled: Bool
    private var trackingArea: NSTrackingArea?

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
        setupSubviews()
        setupGestureRecognizer()
        updateColors()
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
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupSubviews() {
        wantsLayer = true
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
        addGestureRecognizer(clickGestureRecognizer)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if isEnabled {
            setHighlighted(true)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHighlighted(false)
    }

    @objc private func didClick() {
        guard isEnabled, let action = action, let target = target else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    public override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 26)
    }

    public func setHighlighted(_ highlighted: Bool) {
        if #available(macOS 10.14, *) {
            visualEffectView.isEmphasized = highlighted
        } else {
            // Fallback on earlier versions
            visualEffectView.isEmphasized = highlighted
        }

        if highlighted {
            // Use system accent color with appropriate alpha for visibility
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        } else {
            layer?.backgroundColor = nil
        }
    }

    public override func updateLayer() {
        super.updateLayer()
        updateColors()
    }

    private func updateColors() {
        if isEnabled {
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
    }

    public func updateDotColor(_ color: NSColor) {
        dotView?.updateColor(color)
    }

    public var title: String {
        return titleLabel.stringValue
    }

    // MARK: - Loading State

    public func setLoading(_ loading: Bool) {
        if loading {
            dotView?.isHidden = true
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
            dotView?.isHidden = false
        }
    }

    public var isLoading: Bool {
        return loadingIndicator.isHidden == false && loadingIndicator.doubleValue > 0
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
}

// MARK: - Liquid Glass Separator

private class LiquidGlassSeparatorView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let separatorLine: NSBox

    override init(frame frameRect: NSRect) {
        self.visualEffectView = NSVisualEffectView()
        self.separatorLine = NSBox()

        super.init(frame: frameRect)

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
        addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupSeparatorLine() {
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.boxType = .separator
        visualEffectView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            separatorLine.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 12),
            separatorLine.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
            separatorLine.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 12)
    }
}

