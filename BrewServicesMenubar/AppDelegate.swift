//
//  AppDelegate.swift
//  BrewServicesMenubar
//
//  Created by Andrew on 30/04/2016.
//  Copyright © 2016 andrewnicolaou. All rights reserved.
//

import Cocoa

let brewExecutableKey = "brewExecutable"

class Service: NSObject {
    var name = ""
    var state = "unknown" // "started", "stopped", "none", "error", "unknown"
    var user = ""
    var plistPath: String? // Path to plist file if service is configured

    init(name: String, state: String, user: String, plistPath: String? = nil) {
        self.name = name
        self.state = state
        self.user = user
        self.plistPath = plistPath
    }

    // Check if service is configured but not running (likely failed to start)
    var isConfiguredButStopped: Bool {
        // Normalize state to lowercase for comparison
        let normalizedState = state.lowercased()
        return (normalizedState == "stopped" || normalizedState == "none") && plistPath != nil
    }
}

enum BrewServicesMenubarErrors: Error {
    case homebrewNotFound
    case homebrewError
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    // Returns a status item from the system menu bar of variable length
    let statusItem = NSStatusBar.system.statusItem(withLength: -1)
    var services: [Service]?
    var isMenuOpen = false
    var isLoadingServices = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Homebrew can now be located in two different locations depending on how it was installed and what architecture the computer is running
        // Define the most likely path first based on the architecture
        #if arch(arm64)
            UserDefaults.standard.register(defaults: [
                brewExecutableKey: [ "/opt/Homebrew/bin/brew", "/usr/local/bin/brew" ]
            ])
        #elseif arch(x86_64)
            UserDefaults.standard.register(defaults: [
                brewExecutableKey: [ "/usr/local/bin/brew", "/opt/Homebrew/bin/brew" ]
            ])
        #endif

        let icon = NSImage(named: "icon")
        icon?.isTemplate = true

        if let button = statusItem.button {
            button.image = icon
            button.action = #selector(AppDelegate.handleMenuOpen(_:))
            statusItem.menu = statusMenu
            statusMenu.delegate = self
        }

        queryServicesAndUpdateMenu()
    }

    //
    // Event handlers for UI actions
    //
    @objc func handleClick(_ sender: Any) {
        // Get the service name from the view
        var serviceName: String?
        var view: LiquidGlassMenuItemView?

        if let v = sender as? LiquidGlassMenuItemView {
            serviceName = v.title
            view = v
        }

        // Show loading indicator
        view?.setLoading(true)

        // Find the actual service state to toggle it properly
        if let serviceName = serviceName, let services = services {
            if let service = services.first(where: { $0.name == serviceName }) {
                if service.state == "started" {
                    controlService(serviceName, state: "stop")
                } else {
                    controlService(serviceName, state: "start")
                }
            }
        }
    }

    @objc func handleRestartClick(_ sender: Any) {
        // Get the service from the menu item's representedObject
        var service: Service?
        var view: LiquidGlassMenuItemView?

        if let menuItem = sender as? NSMenuItem {
            service = menuItem.representedObject as? Service
            view = menuItem.view as? LiquidGlassMenuItemView
        }

        // Show loading indicator
        view?.setLoading(true)

        if let service = service {
            controlService(service.name, state: "restart")
        }
    }

    @objc func handleStartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "start")
    }

    @objc func handleStopAll(_ sender: NSMenuItem) {
        controlService("--all", state: "stop")
    }

    @objc func handleRestartAll(_ sender: NSMenuItem) {
        controlService("--all", state: "restart")
    }

    @objc func handleQuit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    @objc func handleMenuOpen(_ sender: AnyObject?) {
        isMenuOpen = true
        // Refresh when menu opens to get latest status
        if !isLoadingServices {
            queryServicesAndUpdateMenu()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Refresh services when menu is about to open
        if !isLoadingServices {
            queryServicesAndUpdateMenu()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    // Refresh tracking areas to restore hover functionality after menu updates
    private func refreshTrackingAreas() {
        // Use multiple async dispatches to ensure proper timing
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // First pass: layout all views
            for item in self.statusMenu.items {
                if let view = item.view as? LiquidGlassMenuItemView {
                    view.layoutSubtreeIfNeeded()
                }
            }

            // Second pass: update tracking areas after a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                for item in self.statusMenu.items {
                    if let view = item.view as? LiquidGlassMenuItemView {
                        view.updateTrackingAreas()
                    }
                }
            }
        }
    }

    // Helper method to get dot color for a service state
    private func dotColor(for service: Service) -> NSColor {
        // Normalize state to lowercase for comparison
        let normalizedState = service.state.lowercased()

        switch normalizedState {
        case "started":
            return .systemGreen
        case "stopped", "none":
            // Yellow if configured but stopped (likely failed to start)
            // Red if stopped without plist (not configured or intentionally stopped)
            return service.isConfiguredButStopped ? .systemYellow : .systemRed
        case "unknown", "error":
            return .systemYellow
        default:
            // For any other state, if service has plist but isn't started, show yellow
            // This handles edge cases where state might be unexpected
            if service.plistPath != nil && normalizedState != "started" {
                return .systemYellow
            }
            return .systemYellow
        }
    }

    //
    // Show loading menu with only loading indicator and quit option
    //
    func showLoadingMenu() {
        statusMenu.removeAllItems()

        // Add top spacer for liquid glass effect
        statusMenu.addItem(LiquidGlassMenuItemView.spacer())

        // Add loading indicator
        statusMenu.addItem(LiquidGlassMenuItemView.loading(message: "Loading services..."))

        statusMenu.addItem(LiquidGlassMenuItemView.separator())

        // Add quit item
        let quitItem = LiquidGlassMenuItemView.menuItem(
            title: "Quit",
            dotColor: nil,
            isEnabled: true,
            action: #selector(AppDelegate.handleQuit(_:)),
            target: self,
            accessoryText: "⌘Q"
        )
        statusMenu.addItem(quitItem)

        // Add bottom spacer for liquid glass effect
        statusMenu.addItem(LiquidGlassMenuItemView.spacer())
    }

    //
    // Update existing menu items in place (when menu is open)
    //
    func updateMenuInPlace() {
        guard let services = services else { return }

        // Check if we're coming from a loading state (menu has very few items)
        // If so, rebuild the entire menu
        let expectedMinimumItems = services.count * 2 + 5 // services + alt items + separators + quit + spacers
        if statusMenu.items.count < expectedMinimumItems {
            updateMenu()
            return
        }

        let user = NSUserName()

        // Update each service item
        // Start at index 1 to skip the top spacer
        for (index, service) in services.enumerated() {
            let itemIndex = (index * 2) + 1 // +1 for top spacer, *2 for main + alternate items

            // Safety check - ensure we don't go out of bounds
            guard itemIndex < statusMenu.items.count else {
                // If items are out of sync, rebuild the menu
                updateMenu()
                return
            }

            let menuItem = statusMenu.items[itemIndex]

            // Update the dot color based on current state
            let dotColor = self.dotColor(for: service)

            // Update the custom view's dot color and stop loading
            if let customView = menuItem.view as? LiquidGlassMenuItemView {
                customView.updateDotColor(dotColor)
                customView.setLoading(false)
            }

            // Update enabled state
            let isEnabled = !(service.user != "" && service.user != user)
            menuItem.isEnabled = isEnabled

            // Update alternate item too (itemIndex + 1)
            let altItemIndex = itemIndex + 1
            if altItemIndex < statusMenu.items.count {
                let altMenuItem = statusMenu.items[altItemIndex]
                if let altCustomView = altMenuItem.view as? LiquidGlassMenuItemView {
                    altCustomView.updateDotColor(dotColor)
                    altCustomView.setLoading(false)
                }
                altMenuItem.isEnabled = isEnabled
            }
        }

        // Refresh tracking areas to restore hover functionality after updates
        refreshTrackingAreas()
    }

    //
    // Update menu of services
    //
    func updateMenu(notFound: Bool = false, error: Bool = false) {
        statusMenu.removeAllItems()

        // Add top spacer for liquid glass effect
        statusMenu.addItem(LiquidGlassMenuItemView.spacer())

        if isLoadingServices {
            // Show loading state while fetching services
            let loadingItem = LiquidGlassMenuItemView.loading(message: "Loading services...")
            statusMenu.addItem(loadingItem)

            statusMenu.addItem(LiquidGlassMenuItemView.separator())

            let quitItem = LiquidGlassMenuItemView.menuItem(
                title: "Quit",
                dotColor: nil,
                isEnabled: true,
                action: #selector(AppDelegate.handleQuit(_:)),
                target: self,
                accessoryText: "⌘Q"
            )
            statusMenu.addItem(quitItem)

            // Add bottom spacer
            statusMenu.addItem(LiquidGlassMenuItemView.spacer())
            return
        }

        if notFound {
            let item = LiquidGlassMenuItemView.menuItem(
                title: "Homebrew not found",
                dotColor: nil,
                isEnabled: false,
                action: nil,
                target: nil,
                accessoryText: nil
            )
            statusMenu.addItem(item)
        }
        else if error {
            let item = LiquidGlassMenuItemView.menuItem(
                title: "Homebrew error",
                dotColor: nil,
                isEnabled: false,
                action: nil,
                target: nil,
                accessoryText: nil
            )
            statusMenu.addItem(item)
        }
        else if let services = services {
            let user = NSUserName()
            for service in services {
                // Get dot color for service state
                let dotColor = self.dotColor(for: service)
                let isEnabled = !(service.user != "" && service.user != user)

                // Use LiquidGlassMenuItemView for custom menu items that don't auto-close
                let item = LiquidGlassMenuItemView.menuItem(
                    title: service.name,
                    dotColor: dotColor,
                    isEnabled: isEnabled,
                    action: isEnabled ? #selector(AppDelegate.handleClick(_:)) : nil,
                    target: isEnabled ? self : nil,
                    accessoryText: nil
                )

                statusMenu.addItem(item)

                // Create alternate "Restart" item
                let altItem = LiquidGlassMenuItemView.menuItem(
                    title: "Restart " + service.name,
                    dotColor: dotColor,
                    isEnabled: isEnabled,
                    action: isEnabled ? #selector(AppDelegate.handleRestartClick(_:)) : nil,
                    target: isEnabled ? self : nil,
                    accessoryText: nil
                )
                // Store the service object for later retrieval
                altItem.representedObject = service
                altItem.isAlternate = true
                altItem.isHidden = true
                altItem.keyEquivalentModifierMask = .option
                statusMenu.addItem(altItem)
            }
            if services.count == 0 {
                let item = LiquidGlassMenuItemView.menuItem(
                    title: "No services available",
                    dotColor: nil,
                    isEnabled: false,
                    action: nil,
                    target: nil,
                    accessoryText: nil
                )
                statusMenu.addItem(item)
            }
            else {
                statusMenu.addItem(LiquidGlassMenuItemView.separator())

                let startAllItem = LiquidGlassMenuItemView.menuItem(
                    title: "Start all",
                    dotColor: nil,
                    isEnabled: true,
                    action: #selector(AppDelegate.handleStartAll(_:)),
                    target: self,
                    accessoryText: "⌘S"
                )
                statusMenu.addItem(startAllItem)

                let stopAllItem = LiquidGlassMenuItemView.menuItem(
                    title: "Stop all",
                    dotColor: nil,
                    isEnabled: true,
                    action: #selector(AppDelegate.handleStopAll(_:)),
                    target: self,
                    accessoryText: "⌘X"
                )
                statusMenu.addItem(stopAllItem)

                let restartAllItem = LiquidGlassMenuItemView.menuItem(
                    title: "Restart all",
                    dotColor: nil,
                    isEnabled: true,
                    action: #selector(AppDelegate.handleRestartAll(_:)),
                    target: self,
                    accessoryText: "⌘R"
                )
                statusMenu.addItem(restartAllItem)
            }
        }

        statusMenu.addItem(LiquidGlassMenuItemView.separator())

        let quitItem = LiquidGlassMenuItemView.menuItem(
            title: "Quit",
            dotColor: nil,
            isEnabled: true,
            action: #selector(AppDelegate.handleQuit(_:)),
            target: self,
            accessoryText: "⌘Q"
        )
        statusMenu.addItem(quitItem)

        // Add bottom spacer for liquid glass effect
        statusMenu.addItem(LiquidGlassMenuItemView.spacer())

        // Refresh tracking areas after menu is fully built
        refreshTrackingAreas()
    }

    func queryServicesAndUpdateMenu() {
        // Prevent concurrent brew calls
        if isLoadingServices {
            return
        }

        do {
            let launchPath = try self.brewExecutable()

            // Set loading state and show loading menu if menu is open
            if isMenuOpen && !isLoadingServices {
                isLoadingServices = true
                showLoadingMenu()
            } else if !isLoadingServices {
                // Also set loading state even if menu is closed to prevent concurrent calls
                isLoadingServices = true
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.serviceStates(launchPath: launchPath)
                    DispatchQueue.main.async {
                        self.services = result
                        self.isLoadingServices = false

                        // If menu is open, update in place; otherwise rebuild
                        if self.isMenuOpen {
                            self.updateMenuInPlace()
                        } else {
                            self.updateMenu()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoadingServices = false
                        if !self.isMenuOpen {
                            self.updateMenu(error: true)
                        } else {
                            self.updateMenuInPlace()
                        }
                    }
                }
            }
        } catch {
            isLoadingServices = false
            if !isMenuOpen {
                updateMenu(notFound: true)
            }
        }
    }

    //
    // Locate homebrew
    //
    func brewExecutable() throws -> String {
        // if an array value is set: (the default)
        if let value = UserDefaults.standard.array(forKey: brewExecutableKey) as? [String] {
            for path in value {
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        // if a string value is set:
        if let path = UserDefaults.standard.string(forKey: brewExecutableKey) {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // if homebrew can't be found:
        throw BrewServicesMenubarErrors.homebrewNotFound
    }

    //
    // Changes a service state
    //
    func controlService(_ name:String, state:String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            do {
                task.launchPath = try self.brewExecutable()
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert.init()
                    alert.alertStyle = .critical
                    alert.messageText = "Error locating Homebrew"
                    alert.runModal()

                    // Clear loading state on error
                    self.queryServicesAndUpdateMenu()
                }
                return
            }
            task.arguments = ["services", state, name]

            task.launch()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                DispatchQueue.main.async {
                    let alert = NSAlert.init()
                    alert.alertStyle = .critical
                    alert.messageText = "Could not \(state) \(name)"
                    alert.informativeText = "You will need to manually resolve the issue."
                    alert.runModal()

                    // Refresh menu after error
                    self.queryServicesAndUpdateMenu()
                }
                return
            }

            // Delay the menu update to avoid conflicts with menu being open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.queryServicesAndUpdateMenu()
            }
        }
    }

    //
    // Queries and parses the output of:
    //      brew services list
    //
    func serviceStates(launchPath: String) throws -> [Service] {
        let task = Process()
        let outpipe = Pipe()
        task.launchPath = launchPath
        task.arguments = ["services", "list"]
        task.standardOutput = outpipe

        task.launch()
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw BrewServicesMenubarErrors.homebrewError
        }

        if var string = String(data: outdata, encoding: String.Encoding.utf8) {
            string = string.trimmingCharacters(in: CharacterSet.newlines)
            return parseServiceList(string)
        }

        return []
    }

    func parseServiceList(_ raw: String) -> [Service] {
        let rawServices = raw.components(separatedBy: "\n")
        return rawServices[1..<rawServices.count].map(parseService)
    }

    func parseService(_ raw:String) -> Service {
        let parts = raw.components(separatedBy: " ").filter() { $0 != "" }

        let name = parts.count >= 1 ? parts[0] : ""
        // Parse state - ensure it's lowercase for consistency
        let state = parts.count >= 2 ? parts[1].lowercased() : "unknown"
        let user = parts.count >= 3 ? parts[2] : ""

        // Extract plist path if present (usually the last part after user)
        // Format: "servicename state user /path/to/plist"
        var plistPath: String? = nil
        if parts.count >= 4 {
            // Join remaining parts as the plist path might contain spaces
            plistPath = parts[3..<parts.count].joined(separator: " ")
        }

        let service = Service(
            name: name,
            state: state,
            user: user,
            plistPath: plistPath
        )

        // Debug: Log service state for troubleshooting
        if name == "mariadb" {
            print("[AppDelegate] Parsed mariadb - state: '\(state)', plistPath: \(plistPath ?? "nil"), isConfiguredButStopped: \(service.isConfiguredButStopped), dotColor: \(dotColor(for: service))")
        }

        return service
    }
}
