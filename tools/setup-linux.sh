#!/usr/bin/env bash
# Build source dependencies already obtained by the user; never installs software.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'Only Linux x86_64 is validated.' >&2; exit 1; }
for tool in cmake ninja c++ git perl make python3 "${GODOT:-godot}"; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool. See README prerequisites." >&2; exit 1; }
done
: "${GODOT_CPP_DIR:?Set pinned godot-cpp checkout; see README}"
: "${LUA_SOURCE_DIR:?Set Lua 5.4.7 source directory; see README}"
: "${FSNET_SOURCE_DIR:?Set external fsnet checkout; see README}"
if [[ -z ${FSNET_LIBRARY:-} ]]; then
  # fsnet CMake fetches its pinned upstream dependencies; network is required.
  fsnet_build_dir=${FSNET_BUILD_DIR:-"$FSNET_SOURCE_DIR/build-amber"}
  cmake -S "$FSNET_SOURCE_DIR" -B "$fsnet_build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DFSNET_WITH_LUA=OFF -DBUILD_TESTING=OFF
  cmake --build "$fsnet_build_dir" --target fsnet --parallel "${BUILD_JOBS:-4}"
  export FSNET_LIBRARY="$fsnet_build_dir/libfsnet.so"
fi
"$root/tools/build.sh"
"$root/tools/import.sh"
"${GODOT:-godot}" --headless --path "$root" --script res://tests/test_menu.gd
printf '%s\n' 'Source setup finished. Run ./tools/run.sh; restart any already-open Godot editor.'
