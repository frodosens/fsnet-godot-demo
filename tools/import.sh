#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Godot 4.6.3 cold-import deferred docs race: upstream godotengine/godot#111645.
# Do not ignore failures; allow editor frames to finish before import exits.
"${GODOT:-godot}" --headless --editor --path "$root" --import --frame-delay 800
