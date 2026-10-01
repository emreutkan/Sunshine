#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
/usr/bin/clang -fobjc-arc -Wall -Wextra -framework AppKit -framework Foundation -framework CoreGraphics \
  "$script_dir/config_test.m" -o "$test_dir/config-test"
"$test_dir/config-test"
