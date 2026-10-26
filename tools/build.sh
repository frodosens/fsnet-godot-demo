#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
: "${GODOT_CPP_DIR:?Set pinned godot-cpp source directory; see README}"
: "${LUA_SOURCE_DIR:?Set unmodified Lua 5.4.7 source directory}"
: "${FSNET_SOURCE_DIR:?Set external fsnet checkout directory}"
: "${FSNET_LIBRARY:?Set absolute path to built libfsnet.so}"
revision=$(git -C "$GODOT_CPP_DIR" rev-parse HEAD)
if [[ "$revision" != 507ed9d840c01a3c5b2a39af8bb4000bfac30bf5 ]]; then
  echo "Expected godot-cpp 10.0.0-stable (507ed9d...)" >&2; exit 1
fi
cmake -S "$root" -B "$root/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DGODOT_CPP_DIR="$GODOT_CPP_DIR" -DLUA_SOURCE_DIR="$LUA_SOURCE_DIR" \
  -DFSNET_SOURCE_DIR="$FSNET_SOURCE_DIR" -DFSNET_LIBRARY="$FSNET_LIBRARY"
cmake --build "$root/build" --parallel "${BUILD_JOBS:-4}"
