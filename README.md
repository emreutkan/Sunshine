# Sunshine (macOS cursor fork)

## Moonlight

**Optimize mouse for remote desktop instead of games** must be turned **on**.

Once connected, press **Ctrl + Alt + Shift + C** to reveal the Windows cursor.

Ctrl+Alt+Shift+C does nothing while that setting is off, and the state resets on
every connect, so press it each session. Without both there is no pointer at
all — this fork removes the macOS cursor from the video, so the client has to
draw its own.

Ctrl+Alt+Shift+Z releases the pointer and keyboard back to Windows without
disconnecting. Click back into the video to re-grab.

Ctrl+Alt+Shift+D minimizes the stream. Set Moonlight's display mode to
**borderless windowed** to make that fast — exclusive fullscreen has to change
the display mode on the way out and back in.

## Build

Dependencies:

```bash
brew install boost cmake miniupnpc ninja node openssl@3 opus pkg-config qtbase qtsvg
```

Configure. Docs need doxygen+graphviz and fail the configure step without them,
so they are off. The env vars only set the reported version string; without
them it builds as 0.0.0:

```bash
BRANCH=master BUILD_VERSION=2026.826.1805 COMMIT=$(git rev-parse HEAD) cmake -B build -G Ninja -S . -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF
```

Build:

```bash
ninja -C build
```

Output is `build/Sunshine.app`. Install it, then sign it:

```bash
codesign --force --sign "<Apple Development identity>" /Applications/Sunshine.app
```

`security find-identity -v -p codesigning` lists identities.

Do not sign ad-hoc (`--sign -`). An ad-hoc designated requirement is a hash of
the binary, so every rebuild orphans every macOS permission grant — Screen
Recording and Accessibility stay in the list looking enabled while applying to
a build that no longer exists. A development certificate keys the requirement
to the identity instead and the grants survive rebuilds.

Do not pass `--options runtime`. The hardened runtime refuses Homebrew's
`libminiupnpc` over a Team ID mismatch and the app will not start.

`./install-local.sh` does the build, install, sign and relaunch in one step.

Sunshine needs Screen Recording and Accessibility. Accessibility gates
`CGEventPost`; without it the pointer still moves but clicks, scrolling and
keystrokes are silently dropped. Both are requested at startup and the result
is logged to `~/.config/sunshine/sunshine.log`.

## Virtual display sessions on macOS

With a running virtual display, set `output_name` to its numeric CoreGraphics ID
and `dd_configuration_option = ensure_only_display`. Sunshine makes that display
the only active display before capture starts, then restores the original active
displays and their origins when the last client disconnects. The changes are
app-scoped so WindowServer also restores the layout when Sunshine exits.
Mouse coordinates follow the current primary display after a layout change.

Set `dd_resolution_option = disabled` and `dd_refresh_rate_option = disabled`
to keep the virtual display's existing mode. This uses a private macOS enable API;
if the OS rejects disabling displays, Sunshine logs the failure and restores the
layout. The virtual-display helper must remain running during streaming.

To create the virtual display and start Sunshine automatically at login, run
`./scripts/macos/virtual-display/install.sh`. See [automation setup](scripts/macos/virtual-display/README.md).
