import Cocoa
import GameController

final class AppDelegate: NSObject, NSApplicationDelegate {
    // "/play" with no locale shows Xbox's generic marketing page instead of
    // the actual cloud-gaming library. Change this if you're not in Denmark.
    private let xboxCloudGamingURL = URL(string: "https://www.xbox.com/da-DK/play")!

    private var statusItem: NSStatusItem!
    private var chooserWindow: ChooserWindowController?
    private var activeApp: GamingApp?
    private var activeRunningApp: NSRunningApplication?
    private var isSwitching = false

    // Trigger is View+Menu held together, not the Xbox button: macOS
    // reserves the Xbox button for its own overlay, and GeForce NOW
    // separately grabs it for its own in-game menu while it has focus. A
    // two-button chord is also just safer against accidental switches than
    // a single button would be.
    private var viewButtonPressed = false
    private var menuButtonPressed = false
    private var chordAlreadyFired = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("ConsoleSwitcher: launched, pid=\(ProcessInfo.processInfo.processIdentifier)")
        NSApp.setActivationPolicy(.accessory) // background utility, no Dock icon
        setupStatusItem()
        setupControllerObservers()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(runningAppDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    // MARK: - Menu bar (manual fallback / status)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "gamecontroller.fill",
            accessibilityDescription: "Console Switcher"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Launch Xbox Game Pass", action: #selector(menuLaunchEdge), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Launch GeForce NOW", action: #selector(menuLaunchGeForce), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Active App", action: #selector(menuQuitActive), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Console Switcher", action: #selector(quitApp), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func menuLaunchEdge() { switchTo(.edge) }
    @objc private func menuLaunchGeForce() { switchTo(.geforceNow) }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func menuQuitActive() {
        guard let running = activeRunningApp else { return }
        terminate(running) { [weak self] in
            self?.activeApp = nil
            self?.activeRunningApp = nil
        }
    }

    // MARK: - Controller input

    private func setupControllerObservers() {
        // Without this, GameController only delivers live button/axis
        // events to the frontmost app. This app is deliberately never
        // frontmost (accessory policy, no Dock icon, no window until the
        // chooser appears) — so this is what lets it receive input at all
        // while some other app has focus, which is the entire point of a
        // background switcher.
        GCController.shouldMonitorBackgroundEvents = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect, object: nil
        )
        GCController.controllers().forEach(configure)
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    @objc private func controllerConnected(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        configure(controller)
    }

    private func configure(_ controller: GCController) {
        debugLog("ConsoleSwitcher: controller connected: vendor=\(controller.vendorName ?? "?") category=\(controller.productCategory)")
        guard let gamepad = controller.extendedGamepad else {
            debugLog("ConsoleSwitcher: controller has no extendedGamepad profile, cannot read buttons")
            return
        }

        // Logs which physical button was pressed, by name, straight from
        // the hardware — this is what made it possible to confirm the Xbox
        // button never reaches any app (macOS keeps it for its own
        // Games/Arcade overlay) while View/Menu/A/B etc. do. Left in
        // permanently since it's cheap and useful if the mapping ever needs
        // re-checking on different hardware; axis-only elements (sticks,
        // d-pad position) are skipped to avoid flooding the log.
        gamepad.valueChangedHandler = { _, element in
            guard let button = element as? GCControllerButtonInput, button.isPressed else { return }
            let name = element.localizedName ?? element.sfSymbolsName ?? "unnamed button"
            debugLog("ConsoleSwitcher: button pressed: '\(name)'")
        }

        // Not buttonHome: macOS reserves the Xbox/Guide button system-wide
        // for its own Games/Arcade overlay, and GeForce NOW separately
        // grabs it for its own in-game menu — neither leaves anything for a
        // third-party app to see. View+Menu held together is ordinary input
        // neither streaming client depends on.
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.viewButtonPressed = pressed
                self?.checkChordTrigger()
            }
        }
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.menuButtonPressed = pressed
                self?.checkChordTrigger()
            }
        }

        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async { self?.chooserWindow?.moveSelection(-1) }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async { self?.chooserWindow?.moveSelection(1) }
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async { self?.chooserWindow?.confirmSelection() }
        }
    }

    // MARK: - Switching logic

    /// Fires once when both chord buttons become pressed together, not
    /// again until both have been released — so holding them doesn't retrigger.
    private func checkChordTrigger() {
        if viewButtonPressed && menuButtonPressed {
            guard !chordAlreadyFired else { return }
            chordAlreadyFired = true
            handleTrigger()
        } else {
            chordAlreadyFired = false
        }
    }

    private func handleTrigger() {
        guard !isSwitching else { return }
        if chooserWindow != nil { return } // picker already open, ignore repeat presses

        if let active = activeApp {
            switchTo(active == .edge ? .geforceNow : .edge)
        } else {
            showChooser()
        }
    }

    private func showChooser() {
        let chooser = ChooserWindowController { [weak self] choice in
            self?.chooserWindow = nil
            guard let choice else { return }
            self?.switchTo(choice)
        }
        chooserWindow = chooser
        chooser.show()
    }

    private func switchTo(_ target: GamingApp) {
        guard !isSwitching else { return }
        isSwitching = true

        let previous = activeRunningApp
        let launchNext: () -> Void = { [weak self] in
            self?.launch(target)
        }

        if let previous, !previous.isTerminated {
            terminate(previous, then: launchNext)
        } else {
            launchNext()
        }
    }

    private func launch(_ app: GamingApp) {
        guard let url = app.appURL else {
            debugLog("ConsoleSwitcher: \(app.rawValue) is not installed")
            isSwitching = false
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let completion: (NSRunningApplication?, Error?) -> Void = { [weak self] runningApp, error in
            DispatchQueue.main.async {
                if let error {
                    debugLog("ConsoleSwitcher: failed to launch \(app.rawValue): \(error)")
                } else {
                    debugLog("ConsoleSwitcher: launched \(app.displayName)")
                }
                self?.activeApp = app
                self?.activeRunningApp = runningApp
                self?.isSwitching = false
            }
        }

        if app == .edge {
            NSWorkspace.shared.open([xboxCloudGamingURL], withApplicationAt: url, configuration: config, completionHandler: completion)
        } else {
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: completion)
        }
    }

    /// Waits for a graceful quit, then force-terminates if it doesn't
    /// respond — "fully closes" means the couch controller can't leave a
    /// zombie GeForce NOW session pinning the GPU.
    private func terminate(_ app: NSRunningApplication, then completion: @escaping () -> Void) {
        if app.isTerminated {
            completion()
            return
        }
        debugLog("ConsoleSwitcher: terminating \(app.bundleIdentifier ?? "?")")
        app.terminate()

        var attempts = 0
        func poll() {
            attempts += 1
            if app.isTerminated {
                debugLog("ConsoleSwitcher: \(app.bundleIdentifier ?? "?") quit")
                completion()
            } else if attempts >= 20 { // ~5s
                debugLog("ConsoleSwitcher: \(app.bundleIdentifier ?? "?") didn't quit gracefully, force-terminating")
                app.forceTerminate()
                completion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: poll)
            }
        }
        poll()
    }

    @objc private func runningAppDidTerminate(_ note: Notification) {
        guard let terminated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        guard terminated.processIdentifier == activeRunningApp?.processIdentifier else { return }
        // Someone quit the active app by hand (Cmd+Q, Dock, etc). Next Xbox
        // button press should show the chooser again, not assume it's on.
        activeApp = nil
        activeRunningApp = nil
    }
}
