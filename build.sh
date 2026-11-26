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

cdhash() {
    codesign -dvvv "$1" 2>&1 | sed -n 's/^CDHash=//p'
}
PREVIOUS_HASH=""
if [ -d /Applications/Backspin.app ]; then
    PREVIOUS_HASH="$(cdhash /Applications/Backspin.app)"
fi

pkill -x Backspin 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x Backspin >/dev/null || break
    sleep 0.3
done

rm -rf /Applications/Backspin.app
cp -R Backspin.app /Applications/Backspin.app

# An ad hoc signature identifies one exact build. After a rebuild, the Accessibility permission granted
# to the previous build no longer applies, yet System Settings would still show it switched on.
# Clearing it makes macOS ask again instead of leaving a switch that does nothing.
if [ -n "$PREVIOUS_HASH" ] && [ "$PREVIOUS_HASH" != "$(cdhash /Applications/Backspin.app)" ]; then
    if tccutil reset Accessibility dev.alexissantos.backspin >/dev/null 2>&1; then
        echo "Backspin was rebuilt, so its Accessibility permission was cleared. Choose Allow Pasting in the panel to grant it again."
    fi
fi

open /Applications/Backspin.app
