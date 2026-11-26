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

# Sign with the local certificate from make-signing-cert.sh when there is one, so the Accessibility
# permission survives rebuilds. Otherwise sign ad hoc. BACKSPIN_SIGN_IDENTITY overrides both.
IDENTITY="${BACKSPIN_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && security find-certificate -c "Backspin Local Signing" >/dev/null 2>&1; then
    IDENTITY="Backspin Local Signing"
fi
codesign --force --sign "${IDENTITY:--}" Backspin.app

if [ "${1:-}" = "--no-install" ]; then
    exit 0
fi

# What macOS checks a saved permission against: the certificate for a signed build, the exact build for an ad hoc one.
requirement() {
    codesign -d -r- "$1" 2>&1 | sed -n 's/^.*designated => //p'
}
PREVIOUS_REQUIREMENT=""
if [ -d /Applications/Backspin.app ]; then
    PREVIOUS_REQUIREMENT="$(requirement /Applications/Backspin.app)"
fi

pkill -x Backspin 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x Backspin >/dev/null || break
    sleep 0.3
done

rm -rf /Applications/Backspin.app
cp -R Backspin.app /Applications/Backspin.app

# When the new build no longer satisfies what the old permission was saved against (always the case
# between ad hoc builds), the Accessibility permission stops applying, yet System Settings would still
# show it switched on. Clearing it makes macOS ask again instead of leaving a switch that does nothing.
if [ -n "$PREVIOUS_REQUIREMENT" ] && [ "$PREVIOUS_REQUIREMENT" != "$(requirement /Applications/Backspin.app)" ]; then
    if tccutil reset Accessibility dev.alexissantos.backspin >/dev/null 2>&1; then
        echo "Backspin was rebuilt, so its Accessibility permission was cleared. Choose Allow Pasting in the panel to grant it again."
    fi
fi

open /Applications/Backspin.app
