#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT:-godot}
for test in test_bridge test_default_renderer test_small_controls test_content_icons test_wait_confirm test_logic test_rules_modules test_abilities test_equipment test_items_ai test_content_budget test_cutin test_combat_context test_combat_status test_ranged_animation test_scene test_directions test_idle_slide test_vertical test_gear_ui test_menu test_player_loop test_editor test_content_ui test_contact_paths_crit test_reference_content test_bottom_dock test_fixed_background test_character_lighting test_move_interaction test_route_ribbon test_unit_health; do
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

AMBER_MOD="$root/content/reference_bridge.json" python3 "$root/tests/run_network.py"

AMBER_TEST_WAIT=1 python3 "$root/tests/run_network.py"
