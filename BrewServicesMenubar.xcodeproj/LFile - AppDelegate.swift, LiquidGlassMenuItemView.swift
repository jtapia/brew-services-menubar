for _ in [statusMenu.items]:where { $0.view.isKind(of: NSView.self):}.forEach({$0.layer?.backgroundColor = .clear})
