#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT:-godot}
for test in test_bridge test_logic test_rules_modules test_abilities test_equipment test_items_ai test_content_budget test_cutin test_ranged_animation test_scene test_directions test_motion test_vertical test_gear_ui test_menu test_editor; do
  output=$(mktemp)
  if ! "$godot_bin" --headless --path "$root" --script "res://tests/$test.gd" >"$output" 2>&1; then
    cat "$output"; rm "$output"; exit 1
  fi
  cat "$output"
  if grep -Eq 'SCRIPT ERROR|ERROR:|FAIL:' "$output"; then rm "$output"; exit 1; fi
  rm "$output"
done
python3 "$root/tests/run_network.py"

python3 "$root/tests/run_network.py" --extended

python3 "$root/tests/run_network.py" --extended --mod-fixture
