#!/bin/sh
# Build a native helper and start it automatically in this user's GUI session.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
support="$HOME/Library/Application Support/Sunshine/virtual-display"
agent="$HOME/Library/LaunchAgents/dev.sunshine.virtualdisplay.plist"
label=dev.sunshine.virtualdisplay
domain="gui/$(id -u)"
mkdir -p "$support" "$HOME/Library/LaunchAgents"
/usr/bin/clang -fobjc-arc -O2 -Wall -Wextra -framework AppKit -framework Foundation -framework CoreGraphics \
  "$script_dir/main.m" -o "$support/virtual-display.new"
/usr/bin/plutil -create xml1 "$agent.new"
/usr/bin/plutil -insert Label -string "$label" "$agent.new"
/usr/bin/plutil -insert Program -string "$support/virtual-display" "$agent.new"
/usr/bin/plutil -insert RunAtLoad -bool YES "$agent.new"
/usr/bin/plutil -insert KeepAlive -bool YES "$agent.new"
/usr/bin/plutil -insert ThrottleInterval -integer 30 "$agent.new"
/usr/bin/plutil -insert ExitTimeOut -integer 20 "$agent.new"
/usr/bin/plutil -insert LimitLoadToSessionType -string Aqua "$agent.new"
/usr/bin/plutil -insert StandardOutPath -string "$support/helper.log" "$agent.new"
/usr/bin/plutil -insert StandardErrorPath -string "$support/helper-error.log" "$agent.new"
# Restore the physical screen before replacing an existing virtual display.
"$support/virtual-display.new" --stop-sunshine
launchctl bootout "$domain/$label" 2>/dev/null || true
launchctl remove local.moonlight.virtual-display 2>/dev/null || true
mv "$support/virtual-display.new" "$support/virtual-display"
mv "$agent.new" "$agent"
launchctl enable "$domain/$label"
launchctl bootstrap "$domain" "$agent"
printf 'Installed login automation: %s\nLogs: %s\n' "$agent" "$support"
