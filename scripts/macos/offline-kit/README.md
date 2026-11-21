# Sunshine offline kit for macOS

This kit installs Sunshine on a Mac with Apple silicon that has no internet.
A Windows PC with Moonlight connects to it over the local network.

## Contents

- `Sunshine.app`: the macOS-only fork with all libraries inside the app.
  It needs no Homebrew.
- `virtual-display`: the helper that creates a 2560x1440 120 Hz virtual
  display, makes it the only active display while a client streams, and
  starts Sunshine.
- `install.sh`, `uninstall.sh`: install and remove.
- `sunshine.conf`: default settings for Wi-Fi (30 Mbps cap, 40% error
  correction). The installer uses it only when no settings exist yet.

## Install

1. Copy the unzipped folder to the Mac (USB drive or local network).
2. In Terminal, run `./install.sh` from that folder as your own user.
3. Allow Screen Recording and Accessibility for Sunshine in
   System Settings > Privacy & Security. Then run `pkill -x Sunshine`.
   The helper starts Sunshine again.
4. Open `https://localhost:47990`, create the web UI user, and pair Moonlight
   with the PIN.

## Moonlight settings on the Windows PC

- Resolution 2560x1440, 120 FPS.
- Turn on "Optimize mouse for remote desktop instead of games". After you
  connect, press Ctrl+Alt+Shift+C to show the Windows cursor.
- Ctrl+Alt+Shift+Z releases the mouse and keyboard. Ctrl+Alt+Shift+D
  minimizes the stream (use borderless windowed mode).

## Remove

Run `./uninstall.sh`. Add `--all` to remove settings and paired clients too.
