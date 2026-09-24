import Cocoa

/// The couch-distance picker shown the first time the Xbox button is
/// pressed with nothing running. Navigable with a mouse click, or with the
/// controller: d-pad left/right moves the highlight, A confirms.
final class ChooserWindowController: NSWindowController {
    typealias Completion = (GamingApp?) -> Void

    private let completion: Completion
    private var buttons: [NSButton] = []
    private var selectedIndex = 0 {
        didSet { highlightSelection() }
    }

    init(completion: @escaping Completion) {
        self.completion = completion
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 280),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.center()
        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func show() {
        selectedIndex = 0
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func moveSelection(_ delta: Int) {
        selectedIndex = (selectedIndex + delta + buttons.count) % buttons.count
    }

    func confirmSelection() {
        finish(with: selectedIndex == 0 ? .edge : .geforceNow)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "What do you want to play?")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(title)

        let edgeButton = makeButton(title: "🎮  Xbox Game Pass", tag: 0, action: #selector(chooseEdge))
        let gfnButton = makeButton(title: "☁️  GeForce NOW", tag: 1, action: #selector(chooseGeForce))
        buttons = [edgeButton, gfnButton]

        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.spacing = 28
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let hint = NSTextField(labelWithString: "Click one, or use the d-pad + A on the controller")
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 32),
            title.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 6),
            stack.heightAnchor.constraint(equalToConstant: 130),

            hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            hint.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        ])

        highlightSelection()
    }

    private func makeButton(title: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.tag = tag
        button.bezelStyle = .regularSquare
        button.font = .systemFont(ofSize: 22, weight: .medium)
        button.wantsLayer = true
        button.layer?.cornerRadius = 14
        return button
    }

    private func highlightSelection() {
        for (index, button) in buttons.enumerated() {
            button.layer?.borderWidth = index == selectedIndex ? 3 : 0
            button.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
    }

    @objc private func chooseEdge() { finish(with: .edge) }
    @objc private func chooseGeForce() { finish(with: .geforceNow) }

    private func finish(with choice: GamingApp?) {
        window?.close()
        completion(choice)
    }
}
