#!/bin/sh
# Install Sunshine and its 1440p 120 Hz virtual display on this Mac.
# Needs no internet. Run it from the unzipped kit folder as the user who
# will stream (not with sudo).
set -eu

kit=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
support="$HOME/Library/Application Support/Sunshine/virtual-display"
agent="$HOME/Library/LaunchAgents/dev.sunshine.virtualdisplay.plist"
label=dev.sunshine.virtualdisplay
domain="gui/$(id -u)"
config_dir="$HOME/.config/sunshine"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your own user, not with sudo." >&2
  exit 1
fi
if [ "$(uname -m)" != arm64 ]; then
  echo "This kit is for Apple silicon Macs." >&2
  exit 1
fi

# Stop a running copy. The helper restores the physical display first.
if [ -x "$support/virtual-display" ]; then
  "$support/virtual-display" --stop-sunshine || true
fi
launchctl bootout "$domain/$label" 2>/dev/null || true
pkill -x Sunshine 2>/dev/null || true

echo "Copying Sunshine.app to /Applications"
rm -rf /Applications/Sunshine.app
ditto "$kit/Sunshine.app" /Applications/Sunshine.app
xattr -dr com.apple.quarantine /Applications/Sunshine.app 2>/dev/null || true

mkdir -p "$config_dir"
if [ ! -f "$config_dir/sunshine.conf" ]; then
  cp "$kit/sunshine.conf" "$config_dir/sunshine.conf"
  echo "Wrote default settings to $config_dir/sunshine.conf"
else
  echo "Kept your settings in $config_dir/sunshine.conf"
fi

echo "Installing the virtual display helper"
mkdir -p "$support" "$HOME/Library/LaunchAgents"
cp "$kit/virtual-display" "$support/virtual-display.new"
xattr -d com.apple.quarantine "$support/virtual-display.new" 2>/dev/null || true
mv "$support/virtual-display.new" "$support/virtual-display"
cat > "$agent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>Program</key>
	<string>$support/virtual-display</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>30</integer>
	<key>ExitTimeOut</key>
	<integer>20</integer>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>StandardOutPath</key>
	<string>$support/helper.log</string>
	<key>StandardErrorPath</key>
	<string>$support/helper-error.log</string>
</dict>
</plist>
EOF
launchctl enable "$domain/$label"
launchctl bootstrap "$domain" "$agent"

cat <<EOF

Sunshine is installed and starts at login with a 2560x1440 120 Hz virtual display.

Finish the setup:
1. macOS asks for Screen Recording and Accessibility for Sunshine. Allow both in
   System Settings > Privacy & Security, then run: pkill -x Sunshine
   (the helper starts it again within 5 seconds).
2. Open https://localhost:47990 on this Mac. Accept the certificate warning,
   then create the web UI user name and password.
3. In Moonlight on the Windows PC, add this Mac by its IP address:
EOF
ipconfig getifaddr en0 2>/dev/null | sed 's/^/     Ethernet: /' || true
ipconfig getifaddr en1 2>/dev/null | sed 's/^/     Wi-Fi:    /' || true
cat <<EOF
   Enter the PIN that Moonlight shows on the PIN page of the web UI.

Logs: $config_dir/sunshine.log and $support/
EOF
