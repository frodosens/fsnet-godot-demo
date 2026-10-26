#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -f "$root/bin/libamber.so" ]]; then
  echo 'Missing native extension bin/libamber.so. Build with tools/build.sh first (see README). Source clone is not a ready-to-play package.' >&2
  exit 1
fi
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
  echo 'This launcher currently supports Linux x86_64 only; no verified Windows/macOS package is provided.' >&2
  exit 1
fi
exec "${GODOT:-godot}" --path "$root" "$@"
