# Windows x86_64 native runtime candidate

This branch adds real Windows binaries to `bin/windows/x86_64`, so an ordinary
clone contains Amber + fsnet + the required C++ runtime. No Git LFS pointers or
compiler installation are required. Each file is below 12 MiB. This is a Godot
project, not a standalone executable or installer.

Use official Godot **4.6.3 standard Windows x86_64** (not ARM64). Close the editor,
pull this branch, confirm all four DLLs listed in `manifest.json` exist, and reopen
`project.godot`. Keep the DLLs together. Windows 10/11 with UCRT is the intended
target. If loading fails, retain the console's missing DLL name and Windows error
code. Do not delete saves or copy unrelated system DLLs into the project.

**Windows execution is not verified.** PE AMD64, the `amber_library_init` export,
recursive non-system dependency closure and 151 inter-DLL symbol matches passed
on Linux using LLVM readobj. Current `native/*` sources are byte-identical to the
cross-built revision in the manifest; UI/Lua changes load from the current project.
Do not interpret this inspection as a successful Windows New Game playthrough.
Linux declarations are unchanged and Linux still needs its normal local build.

## Provenance and rebuilding

The manifest records binary hashes, sizes, source hashes and exact dependency
pins. `tools/windows/build_cross.sh` accepts verified local sources only, archives
the pinned fsnet revision privately, uses static OpenSSL `mingw64`, adds Asio's
required `mswsock` link, and stages dynamic Windows dependencies. No downloads,
system changes, signing, publishing, SDKs or credentials are part of this script.
Required environment variables are documented at the start of the script.
Official LLVM-MinGW release:
https://github.com/mstorsjo/llvm-mingw/releases/tag/20261020

Run `python3 tools/windows/stage_runtime.py bin/windows/x86_64 "$LLVM_MINGW_ROOT"`
for PE/dependency validation. Bundled Lua/godot-cpp are static in Amber; OpenSSL,
SQLiteCpp/SQLite and libjuice are static in fsnet. libc++ and libunwind are adjacent
DLLs. Windows/UCRT system DLLs are not redistributed.

License texts and source notices are in `bin/windows/x86_64/licenses`. Libjuice
is MPL-2.0, unmodified; its corresponding source is publicly available at the
exact version URL in SOURCES.txt. LLVM includes its exceptions; Lua, godot-cpp,
SQLiteCpp, Asio and OpenSSL notices are retained. Fsnet belongs to the requesting
repository owner, who expressly authorized runtime binary publication here; its
pinned source has no separate license file. No new redistribution permission for
other parties is implied. No toolchain archives, private credentials or demo media
are included.

`.gdextension` dependencies also declare export copies, following the official
format: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdextension/gdextension_file.html
Actual Windows export/runtime verification remains outstanding.
