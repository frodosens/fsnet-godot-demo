#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT:-godot}
for test in test_bridge test_logic test_scene test_vertical test_menu; do
  output=$(mktemp)
  if ! "$godot_bin" --headless --path "$root" --script "res://tests/$test.gd" >"$output" 2>&1; then
    cat "$output"; rm "$output"; exit 1
  fi
  cat "$output"
  if grep -Eq 'SCRIPT ERROR|ERROR:|FAIL:' "$output"; then rm "$output"; exit 1; fi
  rm "$output"
done
python3 "$root/tests/run_network.py"
