#!/bin/bash
# One-click demo launcher for macOS: double-click this file in Finder.
# Starts the FastAPI server, then runs the Flutter app.
#   ./run_demo.command          -> in Chrome, at http://localhost:8080 (no questions asked)
#   ./run_demo.command iphone   -> install on the connected iPhone (or double-click run_on_iphone.command)
#   ./run_demo.command <id>     -> any other device id from `flutter devices`
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
DEVICE="${1:-}"
# Finder starts scripts with a minimal PATH: add the usual install locations.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/flutter/bin:$HOME/development/flutter/bin:$PATH"

say_step() { printf "\n\033[1;36m==> %s\033[0m\n" "$1"; }
fail() { printf "\n\033[1;31m%s\033[0m\n" "$1"; read -r -p "Press Enter to close..." _; exit 1; }

command -v python3 >/dev/null || fail "Python 3 is not installed. Get it from https://www.python.org/downloads/"
if ! command -v flutter >/dev/null; then
  if command -v brew >/dev/null; then
    read -r -p "Flutter is not installed. Install it now with Homebrew (about 2 GB)? [y/N] " answer
    # "н" is the Y key on the Russian keyboard layout, "д" is for "да".
    case "$answer" in
      y|Y|н|Н|д|Д|yes|да) ;;
      *) fail "Flutter is required. Run this file again and answer y." ;;
    esac
    brew install --cask flutter
  else
    fail "Flutter is not installed. Install Homebrew (https://brew.sh), then run:  brew install --cask flutter"
  fi
fi

say_step "1/3 Preparing the server"
cd "$ROOT/server"
[ -d .venv ] || python3 -m venv .venv
./.venv/bin/pip install -q -r requirements.txt

say_step "2/3 Starting the server on http://localhost:8000"
# A server left running by an earlier launch may be an older version of the code: restart it.
if pkill -f "uvicorn app.main:app" 2>/dev/null; then
  echo "Restarting the server that was already running."
  sleep 1
fi
./.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$ROOT/server/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8000/health >/dev/null && break; sleep 1; done
curl -sf http://127.0.0.1:8000/health >/dev/null || fail "The server did not start. See server/server.log"
echo "API docs: http://localhost:8000/docs"

say_step "3/3 Running the app (the first build takes a few minutes)"
cd "$ROOT/app"
flutter pub get
if [ "$DEVICE" = "iphone" ]; then
  # Real iPhone over Wi-Fi: the phone must reach this Mac by its network address.
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
  [ -n "$IP" ] || fail "This Mac is not connected to Wi-Fi. Connect the Mac and the iPhone to the same network."
  PHONE_ID="$(flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
devices = json.load(sys.stdin)
ids = [d["id"] for d in devices if str(d.get("targetPlatform", "")).startswith("ios") and not d.get("emulator")]
print(ids[0] if ids else "")')"
  [ -n "$PHONE_ID" ] || fail "No iPhone found. Unlock it, connect it by cable, tap Trust, and turn on Developer Mode (Settings > Privacy & Security)."
  if ! grep -q "DEVELOPMENT_TEAM" ios/Runner.xcodeproj/project.pbxproj; then
    echo
    echo "One-time step: the app must be signed with your Apple ID."
    echo "  1. Xcode opens now. Click Runner (top of the left panel) > target Runner > Signing & Capabilities."
    echo "  2. Tick 'Automatically manage signing' and choose your Team (your Apple ID, Personal Team)."
    echo "  3. Come back to this window."
    open ios/Runner.xcworkspace
    read -r -p "Press Enter here when the Team is selected..." _
  fi
  echo "Server address for the phone: http://$IP:8000"
  echo "Installing on the iPhone (the first build takes 5-10 minutes)..."
  flutter run --release -d "$PHONE_ID" --dart-define=API_URL="http://$IP:8000"
elif [ -n "$DEVICE" ]; then
  flutter run -d "$DEVICE"
else
  echo "Opening the app in Chrome at http://localhost:8080"
  flutter run -d chrome --web-port 8080
fi
