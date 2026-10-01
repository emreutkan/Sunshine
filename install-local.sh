#!/bin/sh
# Build, install and sign the local Sunshine patch.
# Signing with a real identity (not ad-hoc) keeps the designated requirement
# stable across rebuilds, so macOS permission grants survive.
set -e
cd "$(dirname "$0")"
ninja -C build
pkill -x Sunshine 2>/dev/null || true
sleep 2
rm -rf /Applications/Sunshine.app
cp -R build/Sunshine.app /Applications/Sunshine.app
codesign --force --sign "Apple Development: IRFAN EMRE UTKAN (R6FZ889458)" /Applications/Sunshine.app
open -a /Applications/Sunshine.app
