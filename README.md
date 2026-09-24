# Console Switcher

Turns a Mac hooked up to a TV into a two-game "console": hold View+Menu
together on an Xbox controller to pick Xbox Cloud Gaming (via Microsoft
Edge) or NVIDIA GeForce NOW, and do it again to switch to the other one.
The app that was running gets fully quit — not backgrounded — before the
next one launches, so the couch controller never has to touch a keyboard.

It's a small background menu-bar utility (no Dock icon), built with Swift
and Apple's `GameController` framework.

## How it behaves

- **Nothing running, hold View+Menu** → a chooser pops up: "Xbox Game Pass"
  or "GeForce NOW". Pick one with a click, or with the controller (d-pad
  left/right to move the highlight, A to confirm).
- **Something already running, hold View+Menu** → it quits and the other
  one launches. No picker, since with two options a toggle is unambiguous.
- **You quit the active app yourself** (Cmd+Q, Dock, etc.) → the app notices
  and the next View+Menu press shows the chooser again instead of assuming
  something is still on.
- A menu-bar icon (a gamepad glyph) gives manual "Launch X" / "Quit Active
  App" controls too, for whenever a mouse is easier than the controller.

## Requirements

- macOS 12+, an Xbox controller paired over Bluetooth (or wired).
- [Microsoft Edge](https://www.microsoft.com/edge) and
  [GeForce NOW](https://www.nvidia.com/geforce-now/) installed in
  `/Applications`.
- Xcode Command Line Tools (`xcode-select --install`) to build.

## Why View+Menu, not the Xbox button

The obvious trigger would be the Xbox/Guide button itself
(`GCExtendedGamepad.buttonHome` in Apple's API). It doesn't work, for two
separate reasons found on real hardware:

- macOS reserves it system-wide to open its own Games/Arcade overlay — no
  app ever sees that press at all, confirmed by logging every button the
  controller reports. There's no public API to override that.
- GeForce NOW separately grabs it for its own in-app menu whenever it has
  focus, so even if macOS let it through, GeForce NOW would eat it too.

View and Menu held together is ordinary input neither streaming client
depends on for anything, so it's free to repurpose. To use different
buttons, edit `checkChordTrigger`/`configure` in
`Sources/ConsoleSwitcher/AppDelegate.swift`.

## A real gotcha: this must run as a proper .app, not a bare binary

`swift build` produces a plain Unix executable. Running that directly
connects to the controller fine (you get a `GCControllerDidConnect`
notification, correct vendor name, everything looks normal) but **no
button-press event ever arrives, for any button** — confirmed by logging
every element the gamepad reports. Two things fix it:

1. The binary needs to run from inside a real `.app` bundle
   (`Contents/MacOS/` + `Contents/Info.plist`) so it has a proper bundle
   identity — `build.sh` handles this.
2. `GCController.shouldMonitorBackgroundEvents = true` has to be set in
   code (already is, in `setupControllerObservers()`). Without it,
   GameController only delivers live input to the frontmost app — and this
   app is deliberately never frontmost, since the whole point is switching
   from whatever full-screen game currently has focus.

Always build and run through `build.sh` / the resulting `.app`, not
`.build/release/ConsoleSwitcher` directly.

## Build & run

```sh
./build.sh
open ConsoleSwitcher.app
```

To install it somewhere permanent:

```sh
sudo cp -R ConsoleSwitcher.app /Applications/ConsoleSwitcher.app
```

## Run it automatically at login

A LaunchAgent is included in `launchagent/`. It assumes the app lives at
`/Applications/ConsoleSwitcher.app` (see the install step above) — edit the
`ProgramArguments` path first if you put it somewhere else.

```sh
cp launchagent/com.deekahy.consoleswitcher.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.deekahy.consoleswitcher.plist
```

## Debugging

Every button press, controller connect, app launch, and app termination is
logged to `/tmp/consoleswitcher_debug.log` (plain file, written directly —
deliberately not `NSLog`/`os_log`, which redact string-interpolated messages
to `<private>` in the unified log by default and made this much harder to
debug than it needed to be). Useful for checking what a controller actually
reports:

```sh
tail -f /tmp/consoleswitcher_debug.log
```

To stop it running at login:

```sh
launchctl unload ~/Library/LaunchAgents/com.deekahy.consoleswitcher.plist
rm ~/Library/LaunchAgents/com.deekahy.consoleswitcher.plist
```

## Notes

- The Xbox Game Pass streaming URL is hard-coded to
  `https://www.xbox.com/da-DK/play` in `AppDelegate.swift` (Xbox's bare
  `/play` page shows a generic marketing page instead of the actual library
  without a locale). Change the locale segment if you're not in Denmark.
- Bundle IDs are pinned in `GamingApp.swift`
  (`com.microsoft.edgemac`, `com.nvidia.gfnpc.mall`) — if NVIDIA or
  Microsoft ever change theirs, update it there.
