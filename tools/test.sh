#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT:-godot}
for test in test_content_picker test_mobile_targeting test_mobile_cutin_layout test_combined_mobile_sequence test_ally_traversal test_event_sequence test_event_sequence_input test_wait_advance test_mobile_touch_camera test_combat_sides test_chapter_checkpoint test_chapter_two test_chapter_two_scene test_chapter_two_playthrough test_tessa_sequence test_tessa_sequence_scene test_tessa_sequence_edges test_route_art test_idle_only test_idle_only_scene test_idle_options test_bram_sequence test_bram_sequence_scene test_bram_sequence_edges test_oren_sequence test_oren_sequence_scene test_oren_sequence_edges test_finn_sequence test_finn_sequence_scene test_finn_sequence_edges test_map_sequence test_map_sequence_scene test_map_sequence_edges test_walk_direction_batch test_oren_map_scale test_walk_cycles test_target_confirm test_bridge test_idle_cycles test_idle_boundaries test_mara_idle_candidate test_all_idle_candidates test_default_renderer test_small_controls test_content_icons test_wait_confirm test_logic test_rules_modules test_abilities test_equipment test_items_ai test_content_budget test_cutin test_combat_context test_combat_status test_cutin_portrait_facing test_battle_idle_candidate test_ranged_idle_candidate test_all_battle_idles test_ranged_animation test_scene test_directions test_idle_slide test_vertical test_gear_ui test_menu test_story_footer_input test_player_loop test_editor test_content_ui test_contact_paths_crit test_reference_content test_bottom_dock test_fixed_background test_lantern_obstacle test_reserve_art test_character_lighting test_character_projection test_move_interaction test_route_ribbon test_unit_health test_health_width; do
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

python3 "$root/tests/run_target_network.py"

python3 "$root/tests/run_walk_network.py"

AMBER_WALK_ACTOR=finn AMBER_WALK_DIRECTION=back_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=oren AMBER_WALK_DIRECTION=back_left python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=oren AMBER_WALK_DIRECTION=back_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=mara AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=bram AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=neri AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=tessa AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=adela AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=elsbet AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=mara AMBER_WALK_DIRECTION=back_left python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=mara AMBER_WALK_DIRECTION=back_right python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=bram AMBER_WALK_DIRECTION=back_left python3 "$root/tests/run_walk_network.py"
AMBER_WALK_ACTOR=bram AMBER_WALK_DIRECTION=back_right python3 "$root/tests/run_walk_network.py"

for direction in front_left front_right back_left back_right; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=mara AMBER_WALK_DIRECTION="$direction" python3 "$root/tests/run_walk_network.py"
done

for direction in front_left front_right back_left back_right; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=finn AMBER_WALK_DIRECTION="$direction" python3 "$root/tests/run_walk_network.py"
done

for direction in front_left front_right back_left back_right; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=oren AMBER_WALK_DIRECTION="$direction" python3 "$root/tests/run_walk_network.py"
done

for direction in front_left front_right back_left back_right; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=bram AMBER_WALK_DIRECTION="$direction" python3 "$root/tests/run_walk_network.py"
done

for actor in neri adela elsbet; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR="$actor" AMBER_WALK_DIRECTION=front_right python3 "$root/tests/run_walk_network.py"
done

for direction in front_left front_right back_left back_right; do
  AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=tessa AMBER_WALK_DIRECTION="$direction" python3 "$root/tests/run_walk_network.py"
done

# Authored chapter-two content: real server, two clients, reconnect/replay.
AMBER_MOD="$root/content/white_elm_watchhouse.json" AMBER_TEST_WAIT=1 python3 "$root/tests/run_network.py"

AMBER_VERIFY_COMBAT_SIDES=1 python3 "$root/tests/run_network.py"

python3 "$root/tests/run_event_network.py"
