#!/bin/sh
# Builds ConsoleSwitcher.app.
#
# This has to be a real .app bundle (Contents/MacOS + Contents/Info.plist),
# not a bare `swift build` binary run directly: on real hardware, a bare
# executable connected to a controller and got a normal GCControllerDidConnect
# notification, but never received a single button-press event no matter what
# was pressed — everything about the connection worked except the one thing
# that mattered. Once it had a proper bundle identity (and
# GCController.shouldMonitorBackgroundEvents was set in code), button events
# started arriving immediately. Ad-hoc codesigning is included too, since an
# unsigned bundle has no stable identity for the system to key permissions to.
set -eu

cd "$(dirname "$0")"

swift build -c release

APP="ConsoleSwitcher.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ConsoleSwitcher "$APP/Contents/MacOS/ConsoleSwitcher"
cp AppBundle/Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
