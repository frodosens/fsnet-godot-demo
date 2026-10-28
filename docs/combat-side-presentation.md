# Own-side-left battle presentation

The cut-in assigns sides before playing each settled event. Units in player-controlled factions stay on the left; their opponents stay on the right even when initiating. Runtime faction/controller identities decide this, not attacker identity or a hard-coded `player1` faction. Current networking is cooperative: every connected client can control the same player-controlled party, with no per-client opposing-faction assignment in Session/Authority. Both clients therefore see the same side assignment. A presentation-only optional viewer faction can override inference; it does not grant command ownership. Same-side interactions and spectators use stable faction/id ordering. Legacy callers without participant identities retain attacker-left fallback.

Existing authored attack geometry is computed unchanged and reflected about the combat stage center when the attacker belongs on the right. Only character/effect textures and their positions are mirrored. Contact sockets, projectile tips, knockback, impact, flash and damage-label positions follow that mapping. UI text, backgrounds, button layout and bars are not mirrored. Status names/HP follow the participants' screen sides. Right portraits remain horizontally flipped inward; left portraits remain unchanged. Original team HP colors remain tied to unit ally identity.

No Lua/native/content, command ordering, hit tick, HP calculation or animation duration changes. Current rules do not emit independent automatic counterattack or miss events: tests cover reversed consecutive attacks and zero-damage presentation, without claiming those gameplay features exist.

Validation entry points:
- `test_combat_sides.gd`: all eight authored identities, two resolutions, inferred/explicit viewer factions, melee/ranged/magic contact, HP/critical/death, reuse, reverse queues, pause/fast-forward/skip, same-side/spectator and missing-identity fallback.
- `AMBER_VERIFY_COMBAT_SIDES=1 python3 tests/run_network.py`: three real processes and reconnect; both clients render forward/reverse synthetic presentation probes using their genuinely synchronized units. Those probes submit no rule commands.
- `capture_combat_sides.gd`: actual shared-Lua Mara attack followed by AI enemy-turn attack, from a clearly labeled adjacent-placement fixture. Normal simulation timing. Optional `AMBER_SIDES_CAPTURE_DIR` writes local images; Movie Maker records offline fixed-step output, not hardware FPS.

Actual graphics tested on Linux Godot 4.6.3 Compatibility/llvmpipe at 1280x800 and 960x600. Windows visual runtime remains untested. Review media stays outside Git.
