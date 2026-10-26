# Validation — 2026-10-26

Environment: Debian 13 x86_64; GCC 14.2; CMake 4.4; Godot 4.6.3.stable.official.7d41c59c4. Release CMake build with godot-cpp `template_debug`, API 4.6, single-precision engine ABI. Lua 5.4.7 source: all 63 upstream .c/.h files byte-compared with the pinned source archive, no differences. godot-cpp commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`.

## Actual completed checks

- Native extension built and loaded by Godot. GDScript -> native -> Lua -> structured state is executed, not mocked.
- `tests/test_bridge.gd`: **111 checks, 0 failures**. Integer/bool/string/StringName transfer; floating/object/oversized input rejection; Lua errors, instruction and memory budgets; recovery after errors; 100 VM creation/destruction cycles; invalid transport parameters and idempotent shutdown.
- `tests/test_logic.gd`: **119 checks, 0 failures**. Three independent VMs execute authoritative commands; illegal moves, occupied/water cells, wrong sequence, friendly attack, action budget, one-use skill, malformed snapshots, duplicate request handling, reconnect replay and hash rejection. Greedy complete battle wins at action **17**, hash `45fe189b6262e2ebb44159f7ee880c428e02f70ce675d3957d40f52facabf904`. Passive strategy reaches defeat.
- `tests/test_scene.gd`: instantiated actual scene; camera-projected mouse move -> command -> Lua state, keyboard end-turn, restart all passed. This is synthetic input testing, not a claim of manual playtesting.
- `tests/run_network.py`: **three OS processes**, actual fsnet::Node loopback RPC, two clients, driver deliberately disconnects after action 2 and starts with a fresh VM before reconnect. Both clients finish action **3**, hash `ae09b741866dc74cc4034cc65d809297613e5ba0109d864e6092fcaee03331ca`; every server reply hash was independently verified by client Lua execution.
- Full test script repeated with the public fsnet **8e4af0c9b73445d999a9e3593c1429c63bbec882** baseline shared library: identical passing checks and hashes. Also passed with local hardening **a26ed9ffe3d1842987c52b36efe10117c5f9791e**. Thus the game does not require an unpublished fsnet patch to build/run this path.
- Headless editor import and scene construction passed. One earlier editor import process aborted after printing completion; later import exited 0 and runtime/test processes exited normally. No blanket claim of editor stability is made from one successful import.
- Actual graphical run: existing Xorg dummy driver on an authenticated local display, no TCP listener; OpenGL 4.5 Mesa 25.0.7, **llvmpipe LLVM 19.1.7** software renderer. `main.gd --capture=...` read the real viewport texture after rendered frames; `docs/amber-bridge-runtime.png` was saved and visually inspected. Adjusted overbright light and camera framing based on that screenshot. Final capture used Dummy audio; VSync unsupported warning remains. No software was installed to enable graphics.

Raw successful test outputs: `docs/test-output.txt`, `docs/public-baseline-test-output.txt`.

## Scope and limitations

This is a source project with a locally verified Linux native build, not a standalone export. No export templates were downloaded and no Windows/macOS/mobile executable was produced. No cross-machine/public-network test, latency SLO, production performance benchmark, hostile-peer audit or native sanitizer run is claimed for the game adapter. fsnet's separate review/performance report is not a benchmark of this game.

Art is original procedural placeholder geometry and pixel textures, not final commissioned assets or sprites cut from a concept image. The selected concept's Library ID was identified, but two standard materialization attempts failed (`download failed`), so its pixels were not inspected in this environment. The scene follows the approved verbal warm mercenary/bridge direction only.

See ARCHITECTURE.md for bounded synchronization and trust assumptions. Public distribution of third-party fsnet code/binaries needs explicit licensing; this repository references it externally and contains neither.
