#!/bin/bash
# Builds Backspin.app, signs it ad hoc, installs it in /Applications and launches it.
# Pass --no-install to stop after building the bundle next to this script.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Backspin"

rm -rf Backspin.app
mkdir -p Backspin.app/Contents/MacOS Backspin.app/Contents/Resources
cp "$BIN" Backspin.app/Contents/MacOS/Backspin
cp Resources/Info.plist Backspin.app/Contents/Info.plist
cp Resources/AppIcon.icns Backspin.app/Contents/Resources/AppIcon.icns
cp -R Resources/*.lproj Backspin.app/Contents/Resources/

codesign --force --sign - Backspin.app

if [ "${1:-}" = "--no-install" ]; then
    exit 0
fi

pkill -x Backspin 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x Backspin >/dev/null || break
    sleep 0.3
done

rm -rf /Applications/Backspin.app
cp -R Backspin.app /Applications/Backspin.app
open /Applications/Backspin.app
