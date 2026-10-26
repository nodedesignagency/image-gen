#!/usr/bin/env bash
# Build Decode and run it in the iOS Simulator.
#
#   ./scripts/run.sh               build, boot a simulator, install, launch
#   ./scripts/run.sh --demo        launch straight into the hands-free demo
#   ./scripts/run.sh --fresh       reinstall from scratch, so onboarding shows again
#   ./scripts/run.sh --no-launch   build and install only
#   SIM="iPhone 16 Pro" ./scripts/run.sh   use a specific simulator
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.nodedesign.decode"
APP="build/Debug-iphonesimulator/Decode.app"
LAUNCH_ARGS=()
FRESH=0
LAUNCH=1

for arg in "$@"; do
  case "$arg" in
    --demo) LAUNCH_ARGS+=(-autopilot YES) ;;
    --fresh) FRESH=1 ;;
    --no-launch) LAUNCH=0 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

if ! xcodebuild -version > /dev/null 2>&1; then
  echo "xcodebuild isn't available. Install Xcode from the App Store, open it once, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi

# Prints the UDID of the last iOS device in `simctl list` output on stdin.
# With a name: that exact device. Without: the newest "iPhone NN Pro".
pick_udid() {
  awk -v want="${1:-}" '
    /^-- iOS/ { ios = 1; next }
    /^-- /    { ios = 0; next }
    !ios      { next }
    want != "" && index($0, want " (") == 0 { next }
    want == "" && $0 !~ /iPhone [0-9]+ Pro \(/ { next }
    match($0, /\([0-9A-F-]+\)/) { last = substr($0, RSTART + 1, RLENGTH - 2) }
    END { print last }'
}

booted_iphone() {
  xcrun simctl list devices booted |
    awk '/iPhone/ && match($0, /\([0-9A-F-]+\)/) { print substr($0, RSTART + 1, RLENGTH - 2); exit }'
}

if [[ -n "${SIM:-}" ]]; then
  UDID=$(xcrun simctl list devices available | pick_udid "$SIM")
  [[ -n "$UDID" ]] || { echo "No simulator named \"$SIM\". See: xcrun simctl list devices available" >&2; exit 1; }
else
  UDID=$(booted_iphone)
  [[ -n "$UDID" ]] || UDID=$(xcrun simctl list devices available | pick_udid)
  [[ -n "$UDID" ]] || UDID=$(xcrun simctl list devices available |
    awk '/^-- iOS/ { ios = 1; next } /^-- / { ios = 0; next }
         ios && /iPhone/ && match($0, /\([0-9A-F-]+\)/) { last = substr($0, RSTART + 1, RLENGTH - 2) }
         END { print last }')
fi
if [[ -z "$UDID" ]]; then
  echo "No iPhone simulator found. In Xcode: Settings → Components, install an iOS simulator." >&2
  exit 1
fi
NAME=$(xcrun simctl list devices | grep "$UDID" | head -1 | sed -E 's/^ *([^(]*) \(.*/\1/')

echo "▸ Building Decode (first build takes a minute)…"
mkdir -p build
if ! xcodebuild \
  -project Decode.xcodeproj \
  -target Decode \
  -configuration Debug \
  -sdk iphonesimulator \
  -arch "$(uname -m)" \
  SYMROOT="$PWD/build" \
  CODE_SIGNING_ALLOWED=NO \
  build > build/build.log 2>&1; then
  grep -E "error:" build/build.log | sort -u | head -20 >&2 || true
  echo "Build failed. Full log: build/build.log" >&2
  exit 1
fi
codesign --force --sign - --timestamp=none "$APP" > /dev/null 2>&1

echo "▸ Booting $NAME…"
xcrun simctl boot "$UDID" 2> /dev/null || true # already booted is fine
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null

if (( FRESH )); then
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2> /dev/null || true
fi
echo "▸ Installing…"
xcrun simctl install "$UDID" "$APP"

if (( LAUNCH )); then
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2> /dev/null || true
  echo "▸ Launching…"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" ${LAUNCH_ARGS[@]+"${LAUNCH_ARGS[@]}"} > /dev/null
  echo "✓ Decode is running on $NAME."
  echo "  Record the screen: xcrun simctl io booted recordVideo --codec=h264 decode.mp4   (Ctrl-C to stop)"
else
  echo "✓ Installed on $NAME ($UDID)."
fi
