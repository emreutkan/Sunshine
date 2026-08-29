# Sunshine (macOS cursor fork)

Fork of [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) with macOS
streaming patches. See upstream for everything else.

## Moonlight setup

Both of these are required, in this order:

1. **Optimize mouse for remote desktop instead of games** must be turned **on**.
2. Once connected, press **Ctrl + Alt + Shift + C** to reveal the Windows cursor.

Step 2 does nothing while step 1 is off — Moonlight refuses the toggle outside
remote desktop mouse mode and logs `Cursor can only be shown in remote desktop
mouse mode`. The visibility state resets on every connect, so step 2 has to be
repeated each session.

Without both, there is no pointer at all: this fork removes the macOS cursor
from the video, so the client has to draw its own.

## Changes

- **Cursor excluded from capture.** `capturesCursor = NO` on the
  `AVCaptureScreenInput`. The streamed macOS cursor was not on a different
  acceleration curve — it lagged the client cursor by the stream latency and
  caught up exactly once movement stopped. Removing it leaves only the client's
  local cursor, with no lag, no duplicate pointer, and no disappearing pointer
  while typing. Sunshine still drives the real macOS pointer, it just stops
  filming it.

- **Accessibility permission is checked and reported.** Every mouse and keyboard
  event ends in `CGEventPost`, which accessibility gates. Cursor motion also
  calls `CGWarpMouseCursorPosition`, which does not need the permission — so
  without it, motion keeps working while clicks, scrolling and keystrokes are
  dropped silently. Nothing requested the permission either, so the app never
  appeared in the Accessibility list to be granted. It is now requested at
  startup, before the screen capture check, so both permissions can be resolved
  in one pass.

- **No encoder reprobing on connect.** The capture session is no longer torn
  down and restarted for every probe.

## Build

```bash
cmake -B build -G Ninja -S . -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF
ninja -C build
```

`./install-local.sh` builds, installs to `/Applications`, re-signs and relaunches.

Sign with a real identity rather than ad-hoc. An ad-hoc signature's designated
requirement is a hash of the binary, so every rebuild orphans every macOS
permission grant — the entries stay in the list looking enabled while applying
to a build that no longer exists. Signing with a development certificate keys
the requirement to the identity instead, and the grants survive rebuilds.
