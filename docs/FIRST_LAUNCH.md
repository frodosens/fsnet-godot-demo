# Clean-clone first launch — 2026-10-26

Baseline: aa48b6f3f755c588451e4d5d2ea948ea989a8eb0. A new local clone (`--no-hardlinks`), no copied bin/build/.godot, empty XDG user/cache directories. Linux x86_64, Godot 4.6.3, Xorg/OpenGL Compatibility, Mesa llvmpipe. No Windows or mobile claim.

## Reproduced failure

Before building: `GDExtension dynamic library not found`, followed by undeclared `AmberTransport` / `AmberLogic` and failure to create App autoload. Source repository omits native binaries. This is a concrete clean-clone failure, not confirmation of the user's as-yet-unknown OS.

Native classes now use runtime lookup so missing binaries cannot prevent the menu from compiling. New Game checks availability, gives platform-specific next steps and returns safely. It does not replace Lua with GDScript. Also fixed first-run network/workshop enumeration of nonexistent user://mods.

## Actual graphical validation

`tests/test_first_launch.gd` sends mouse press/release through the viewport to the real New Game button. With the native library absent it displays the actionable error, creates no session, and the Return button works. Godot's underlying native-load error remains in its output by design.

Then built the native extension from this clone using already installed pinned godot-cpp/Lua sources and an external built fsnet. No warm libamber binary was copied. With another empty user/cache directory, the same real button click entered the story scene; after skipping the story, a viewport target click executed a shared-Lua move to (4,6), step 1. The test advances presentation time to finish the move; this is input/transition evidence, not real-time performance measurement.

Screenshots: [missing component](first-launch-missing-native.jpg), [playable after build](first-launch-playable.jpg).

## User steps and limits

Follow README's Linux build prerequisites, run tools/build.sh, restart the editor and run the project. tools/run.sh rejects a missing binary before launch. If loading fails after building, inspect `ldd bin/libamber.so` and the external libfsnet path. No need to delete saves.

This patch improves source-project startup and verifies Linux entry; it does **not** turn the repository into a portable binary distribution. Windows/macOS native builds and a ready-to-play release remain unavailable/unverified. No fsnet binary redistributed.

## Build / artifact readiness

Game repository has no existing GitHub Actions workflow or downloadable native release. External fsnet's `.github/workflows/cmake.yml` runs Ubuntu builds and publishes a Linux fsnet archive; this is not an Amber GDExtension or Windows artifact. Its OpenSSL build currently invokes make with `-fPIC` and imports `.a` libraries, requiring a real Windows toolchain adaptation before claiming an MSVC pipeline. No Windows SDK/runner or new dependency was installed for this check. Adding a nominal Windows YAML would not make the clone playable.

`tools/setup-linux.sh` provides one checked orchestration entry point using the documented source directories, optionally building external fsnet, then building the bridge, importing and checking menu flow. No compiler-free route is currently available. Native binary distribution (including external fsnet license/packaging) and Windows runtime acceptance remain separate work, not solved by the error message.
