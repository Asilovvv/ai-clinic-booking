#!/bin/bash
# One-click demo launcher for macOS: double-click this file in Finder.
# Starts the FastAPI server, then runs the Flutter app.
#   ./run_demo.command          -> iOS Simulator (or the only connected device)
#   ./run_demo.command chrome   -> in the Chrome browser
#   ./run_demo.command <id>     -> any device id from `flutter devices`
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
DEVICE="${1:-}"

say_step() { printf "\n\033[1;36m==> %s\033[0m\n" "$1"; }
fail() { printf "\n\033[1;31m%s\033[0m\n" "$1"; read -r -p "Press Enter to close..." _; exit 1; }

command -v python3 >/dev/null || fail "Python 3 is not installed. Get it from https://www.python.org/downloads/"
command -v flutter >/dev/null || fail "Flutter is not installed or not in PATH. Install it:  brew install --cask flutter   (or https://docs.flutter.dev/get-started/install), then run this file again."

say_step "1/3 Preparing the server"
cd "$ROOT/server"
[ -d .venv ] || python3 -m venv .venv
./.venv/bin/pip install -q -r requirements.txt

say_step "2/3 Starting the server on http://localhost:8000"
if curl -sf http://127.0.0.1:8000/health >/dev/null; then
  echo "Server is already running."
else
  ./.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$ROOT/server/server.log" 2>&1 &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null' EXIT
  for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8000/health >/dev/null && break; sleep 1; done
  curl -sf http://127.0.0.1:8000/health >/dev/null || fail "The server did not start. See server/server.log"
fi
echo "API docs: http://localhost:8000/docs"

say_step "3/3 Running the app (the first build takes a few minutes)"
cd "$ROOT/app"
flutter pub get
if [ -n "$DEVICE" ]; then
  flutter run -d "$DEVICE"
else
  open -a Simulator 2>/dev/null && sleep 10 || true
  flutter run
fi
