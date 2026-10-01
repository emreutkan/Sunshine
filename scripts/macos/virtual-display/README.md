# Automatic 1440p / 180 Hz display for Sunshine

Requires this Sunshine branch installed as `/Applications/Sunshine.app`, macOS
13 or later, and Apple's command-line build tools. The helper links only Apple
frameworks. The private display interfaces are based on Chromium; its BSD license
is included in `LICENSE`. No downloaded executables or display drivers are used.

Install once from this checkout:

```sh
./scripts/macos/virtual-display/install.sh
```

Installation restarts Sunshine and replaces any helper installed by this setup.
A per-user LaunchAgent then runs after login and restarts the helper if it exits.
It creates a 2560×1440 / 180 Hz virtual display, reads its current display ID,
updates only the relevant Sunshine configuration keys, and starts Sunshine.
The executable is copied to Application Support, so moving the checkout is safe.
A local config backup is saved as `~/.config/sunshine/sunshine.conf.before-virtualdisplay`.
Credentials and pairing state are neither changed nor uploaded.

Sunshine makes the virtual screen the only active display when the first client
connects and restores the original physical displays when the last client
leaves. The hidden Mac cursor and Windows-side Moonlight cursor behavior remain
unchanged. Configure the Windows client for 2560×1440 / 180 FPS yourself; the
virtual display's advertised refresh rate does not prove 180 FPS throughput.

To stop the automation and Sunshine (physical screens are restored first):

```sh
launchctl bootout "gui/$(id -u)/dev.sunshine.virtualdisplay"
```

To resume it:

```sh
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/dev.sunshine.virtualdisplay.plist"
```

To prevent future login startup, stop it as above and move
`~/Library/LaunchAgents/dev.sunshine.virtualdisplay.plist` elsewhere. Before
running Sunshine without the helper, remove `output_name` and the `dd_` options
listed in `configuredText` from `~/.config/sunshine/sunshine.conf`, or restore the
backup after accounting for any other config changes made since installation.

Logs are in `~/Library/Application Support/Sunshine/virtual-display/`.

## Regression checks

`./scripts/macos/virtual-display/test.sh` checks config generation without
changing the real config, launching Sunshine, or creating a display.

After installation, manually check a connect/disconnect cycle: only the virtual
display is active while connected, clicks land under the Windows cursor, and the
physical monitor is restored after disconnect. Log out and in to check startup;
reboot/login validation is intentionally not performed by the installer.
