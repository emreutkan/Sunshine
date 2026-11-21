#!/bin/sh
# Remove Sunshine and the virtual display helper. Keeps ~/.config/sunshine
# (settings, paired clients) unless you pass --all.
set -eu

support="$HOME/Library/Application Support/Sunshine/virtual-display"
agent="$HOME/Library/LaunchAgents/dev.sunshine.virtualdisplay.plist"
label=dev.sunshine.virtualdisplay

if [ -x "$support/virtual-display" ]; then
  "$support/virtual-display" --stop-sunshine || true
fi
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
pkill -x Sunshine 2>/dev/null || true
rm -f "$agent"
rm -rf "$HOME/Library/Application Support/Sunshine" /Applications/Sunshine.app
if [ "${1:-}" = "--all" ]; then
  rm -rf "$HOME/.config/sunshine"
  echo "Removed Sunshine, the helper, settings and paired clients."
else
  echo "Removed Sunshine and the helper. Settings stay in $HOME/.config/sunshine."
fi
