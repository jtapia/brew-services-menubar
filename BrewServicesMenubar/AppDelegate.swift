//
//  AppDelegate.swift
//  BrewServicesMenubar
//
//  Created by Andrew on 30/04/2016.
//  Copyright © 2016 andrewnicolaou. All rights reserved.
//

import Cocoa

fileprivate func statusDot(color: NSColor, diameter: CGFloat = 10) -> NSImage {
    // Standard menu item height on macOS is typically around 22pt
    let menuItemHeight: CGFloat = 22
    let canvas: CGFloat = max(diameter, menuItemHeight)
    let size = NSSize(width: canvas, height: canvas)
    let image = NSImage(size: size)

    image.lockFocus()

    // Center the circle within the canvas, with a slight downward nudge for visual alignment
    let verticalNudge: CGFloat = -0.3
    let origin = NSPoint(x: (canvas - diameter) / 2.0, y: (canvas - diameter) / 2.0 - verticalNudge)
    let rect = NSRect(origin: origin, size: NSSize(width: diameter, height: diameter))
    let path = NSBezierPath(ovalIn: rect)

    color.setFill()
    path.fill()

    image.unlockFocus()
    image.isTemplate = false
    return image
}

let brewExecutableKey = "brewExecutable"

class Service: NSObject {
    var name = ""
    var state = "unknown" // "started", "stopped", "none", "error", "unknown"
    var user = ""

    init(name: String, state: String, user: String) {
        self.name = name
        self.state = state
        self.user = user
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

        if let view = sender as? LiquidGlassMenuItemView {
            serviceName = view.title
        }

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

        if let menuItem = sender as? NSMenuItem {
            service = menuItem.representedObject as? Service
        }

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
        queryServicesAndUpdateMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    //
    // Update existing menu items in place (when menu is open)
    //
    func updateMenuInPlace() {
        guard let services = services else { return }

        let user = NSUserName()

        // Update each service item
        for (index, service) in services.enumerated() {
            let itemIndex = index * 2 // Each service has a main item and an alternate item

            if itemIndex < statusMenu.items.count {
                let menuItem = statusMenu.items[itemIndex]

                // Update the dot color based on current state
                let dotColor: NSColor
                switch service.state {
                case "started":
                    dotColor = .systemGreen
                case "stopped", "none":
                    dotColor = .systemRed
                case "unknown":
                    dotColor = .systemYellow
                default:
                    dotColor = .systemYellow
                }

                // Update the custom view's dot color
                if let customView = menuItem.view as? LiquidGlassMenuItemView {
                    customView.updateDotColor(dotColor)
                }

                // Update enabled state
                let isEnabled = !(service.user != "" && service.user != user)
                menuItem.isEnabled = isEnabled

                // Update alternate item too
                if itemIndex + 1 < statusMenu.items.count {
                    let altMenuItem = statusMenu.items[itemIndex + 1]
                    if let altCustomView = altMenuItem.view as? LiquidGlassMenuItemView {
                        altCustomView.updateDotColor(dotColor)
                    }
                    altMenuItem.isEnabled = isEnabled
                }
            }
        }
    }

    //
    // Update menu of services
    //
    func updateMenu(notFound: Bool = false, error: Bool = false) {
        statusMenu.removeAllItems()

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
                // Add colored status dot before the service name
                let dotColor: NSColor
                switch service.state {
                case "started":
                    dotColor = .systemGreen
                case "stopped", "none":
                    dotColor = .systemRed
                case "unknown":
                    dotColor = .systemYellow
                default:
                    dotColor = .systemYellow
                }

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
                statusMenu.addItem(.separator())

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
    }

    func queryServicesAndUpdateMenu() {
        do {
            let launchPath = try self.brewExecutable()

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.serviceStates(launchPath: launchPath)
                    DispatchQueue.main.async {
                        self.services = result

                        // If menu is open, update in place; otherwise rebuild
                        if self.isMenuOpen {
                            self.updateMenuInPlace()
                        } else {
                            self.updateMenu()
                        }
                    }
                } catch {
                    if !self.isMenuOpen {
                        self.updateMenu(error: true)
                    }
                }
            }
        } catch {
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
                let alert = NSAlert.init()
                alert.alertStyle = .critical
                alert.messageText = "Error locating Homebrew"
                alert.runModal()
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
                }
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
        return Service(
            name: parts.count >= 1 ? parts[0] : "",
            state: parts.count >= 2 ? parts[1] : "unknown",
            user: parts.count >= 3 ? parts[2] : ""
        )
    }
}
