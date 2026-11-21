#!/bin/sh
# Build the offline kit: a self-contained Sunshine.app, the prebuilt virtual
# display helper and the install scripts. Run it on a build Mac; the result
# installs on a Mac with no internet and no Homebrew.
#
# Output: offline-kit/Sunshine-macOS-offline.zip (tracked in git)
#
# Environment:
#   CMAKE_EXTRA_ARGS  extra arguments for the CMake configure step.
#   SIGN_IDENTITY  codesign identity. Default: the first "Apple Development"
#                  identity, else ad-hoc. A real identity keeps macOS
#                  permission grants across reinstalls.
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
kit_src="$repo/scripts/macos/offline-kit"
build="$repo/build-kit"
stage="$repo/dist/Sunshine-macOS-offline"
app="$stage/Sunshine.app"
frameworks="$app/Contents/Frameworks"

cd "$repo"
BRANCH=$(git rev-parse --abbrev-ref HEAD) BUILD_VERSION=${BUILD_VERSION:-2026.826.1805} COMMIT=$(git rev-parse HEAD) \
  cmake -B "$build" -G Ninja -S . -DBUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release ${CMAKE_EXTRA_ARGS:-} >/dev/null
ninja -C "$build"

rm -rf "$stage"
mkdir -p "$stage"
ditto "$build/Sunshine.app" "$app"
mkdir -p "$frameworks"

# Copy every library outside /System and /usr/lib into the bundle and point
# the binaries at the copies. Repeat until no binary refers outside the bundle.
is_external() {
  case "$1" in
    /System/* | /usr/lib/* | @*) return 1 ;;
    *) return 0 ;;
  esac
}
# sh has no local variables, so this makes passes instead of recursing.
changed=1
while [ "$changed" = 1 ]; do
  changed=0
  for binary in "$app/Contents/MacOS/Sunshine" "$frameworks"/*.dylib; do
    [ -f "$binary" ] || continue
    for dep in $(otool -L "$binary" | tail -n +2 | awk '{print $1}'); do
      is_external "$dep" || continue
      name=$(basename "$dep")
      if [ ! -f "$frameworks/$name" ]; then
        cp "$dep" "$frameworks/$name"
        chmod u+w "$frameworks/$name"
        install_name_tool -id "@executable_path/../Frameworks/$name" "$frameworks/$name"
      fi
      install_name_tool -change "$dep" "@executable_path/../Frameworks/$name" "$binary"
      changed=1
    done
  done
done

leftover=$(for f in "$app/Contents/MacOS/Sunshine" "$frameworks"/*; do otool -L "$f" | tail -n +2 | awk '{print $1}'; done |
  grep -v -E '^(/System/|/usr/lib/|@executable_path/)' || true)
if [ -n "$leftover" ]; then
  echo "Libraries outside the bundle remain:" >&2
  echo "$leftover" >&2
  exit 1
fi

identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')}
identity=${identity:--}
for lib in "$frameworks"/*; do
  codesign --force --sign "$identity" "$lib"
done
# No hardened runtime: it would refuse the bundled libraries' team ID.
codesign --force --sign "$identity" "$app"
codesign --verify --deep --strict "$app"

/usr/bin/clang -fobjc-arc -O2 -Wall -Wextra -framework AppKit -framework Foundation -framework CoreGraphics \
  "$repo/scripts/macos/virtual-display/main.m" -o "$stage/virtual-display"

cp "$kit_src/install.sh" "$kit_src/uninstall.sh" "$kit_src/sunshine.conf" "$kit_src/README.md" "$stage/"
chmod +x "$stage/install.sh" "$stage/uninstall.sh"

mkdir -p "$repo/offline-kit"
rm -f "$repo/offline-kit/Sunshine-macOS-offline.zip"
ditto -c -k --keepParent "$stage" "$repo/offline-kit/Sunshine-macOS-offline.zip"
printf 'Signed with: %s\nKit: %s\n' "$identity" "$repo/offline-kit/Sunshine-macOS-offline.zip"
