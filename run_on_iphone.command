#!/bin/bash
# Double-click in Finder: starts the server and installs the app on the connected iPhone.
exec "$(dirname "$0")/run_demo.command" iphone
