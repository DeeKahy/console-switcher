# Console Switcher

Turns a Mac hooked up to a TV into a two-game "console": press the View
button on an Xbox controller to pick Xbox Cloud Gaming (via Microsoft Edge)
or NVIDIA GeForce NOW, and press it again to switch to the other one. The
app that was running gets fully quit — not backgrounded — before the next
one launches, so the couch controller never has to touch a keyboard.

It's a small background menu-bar utility (no Dock icon), built with Swift
and Apple's `GameController` framework.

## How it behaves

- **Nothing running, press View** → a chooser pops up: "Xbox Game Pass" or
  "GeForce NOW". Pick one with a click, or with the controller (d-pad
  left/right to move the highlight, A to confirm).
- **Something already running, press View** → it quits and the other one
  launches. No picker, since with two options a toggle is unambiguous.
- **You quit the active app yourself** (Cmd+Q, Dock, etc.) → the app notices
  and the next View-button press shows the chooser again instead of assuming
  something is still on.
- A menu-bar icon (a gamepad glyph) gives manual "Launch X" / "Quit Active
  App" controls too, for whenever a mouse is easier than the controller.

## Requirements

- macOS 12+, an Xbox controller paired over Bluetooth (or wired).
- [Microsoft Edge](https://www.microsoft.com/edge) and
  [GeForce NOW](https://www.nvidia.com/geforce-now/) installed in
  `/Applications`.
- Xcode Command Line Tools (`xcode-select --install`) to build.

## Why the View button, not the Xbox button

The obvious trigger would be the Xbox/Guide button itself
(`GCExtendedGamepad.buttonHome` in Apple's API). It doesn't work: macOS
reserves that button system-wide to open its own Games/Arcade overlay,
so third-party apps never see the press at all — confirmed on hardware, this
isn't just the well-known iOS/tvOS restriction. There's no public API to
override that reservation.

The View button (`buttonOptions`, left of Menu) is ordinary input that
nothing reserves and that neither Xbox Cloud Gaming nor GeForce NOW depend
on mid-game, so it's free to repurpose. If you'd rather use a different
button, change `gamepad.buttonOptions` in
`Sources/ConsoleSwitcher/AppDelegate.swift` — `buttonMenu` (the Start-style
button) is the other reasonable option, though some games do use it for
their own pause menu.

## Build & run

```sh
swift build -c release
.build/release/ConsoleSwitcher
```

To install it somewhere permanent:

```sh
sudo cp .build/release/ConsoleSwitcher /usr/local/bin/ConsoleSwitcher
```

## Run it automatically at login

A LaunchAgent is included in `launchagent/`. It assumes the binary lives at
`/usr/local/bin/ConsoleSwitcher` (see the install step above) — edit the
`ProgramArguments` path first if you put it somewhere else.

```sh
cp launchagent/com.deekahy.consoleswitcher.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.deekahy.consoleswitcher.plist
```

Logs go to `/tmp/consoleswitcher.log`.

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
