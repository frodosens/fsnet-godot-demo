#!/usr/bin/env bash
# Local preverified sources only. No downloads, signing or uploads.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${LLVM_MINGW_ROOT:?Verified llvm-mingw UCRT Linux x86_64 toolchain}"
: "${FSNET_SOURCE_DIR:?Pinned fsnet git checkout}"
: "${OPENSSL_SOURCE_DIR:?Verified OpenSSL 3.5.9}"
: "${ASIO_SOURCE_DIR:?Verified asio-1-30-2}"
: "${SQLITECPP_SOURCE_DIR:?Verified SQLiteCpp3.3.2}"
: "${LIBJUICE_SOURCE_DIR:?Verified libjuice1.6.2}"
: "${GODOT_CPP_DIR:?Pinned godot-cpp checkout}"
: "${LUA_SOURCE_DIR:?Verified Lua5.4.7}"
[[ $(git -C "$GODOT_CPP_DIR" rev-parse HEAD) == 507ed9d840c01a3c5b2a39af8bb4000bfac30bf5 ]]
export PATH="$LLVM_MINGW_ROOT/bin:$PATH"
mkdir -p "$root/build-windows-cross"
work=$(mktemp -d "$root/build-windows-cross/run.XXXXXX")
mkdir "$work/source"
git -C "$FSNET_SOURCE_DIR" archive 8e4af0c9b73445d999a9e3593c1429c63bbec882 | tar -x -C "$work/source"
cp "$root/tools/windows/OpenSSL.cmake" "$work/source/cmake/OpenSSL.cmake"
printf '\nif(WIN32)\n target_link_libraries(fsnet PRIVATE mswsock)\nendif()\n' >> "$work/source/CMakeLists.txt"
cmake -S "$work/source" -B "$work/fsnet" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE="$root/tools/windows/cross-toolchain.cmake" \
 -DCMAKE_BUILD_TYPE=Release -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON \
 -DFSNET_WITH_LUA=OFF -DFSNET_WITH_POSTGRES=OFF -DBUILD_TESTING=OFF \
 -DAMBER_OPENSSL_SOURCE="$OPENSSL_SOURCE_DIR" -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
 -DFETCHCONTENT_SOURCE_DIR_ASIO="$ASIO_SOURCE_DIR" -DFETCHCONTENT_SOURCE_DIR_SQLITECPP="$SQLITECPP_SOURCE_DIR" \
 -DFETCHCONTENT_SOURCE_DIR_LIBJUICE="$LIBJUICE_SOURCE_DIR"
cmake --build "$work/fsnet" --target fsnet --parallel "${BUILD_JOBS:-4}"
cmake -S "$root" -B "$work/amber" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE="$root/tools/windows/cross-toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
 -DGODOT_CPP_DIR="$GODOT_CPP_DIR" -DLUA_SOURCE_DIR="$LUA_SOURCE_DIR" \
 -DFSNET_SOURCE_DIR="$work/source" -DFSNET_LIBRARY="$work/fsnet/libfsnet.dll.a"
cmake --build "$work/amber" --parallel "${BUILD_JOBS:-4}"
cp "$work/fsnet/libfsnet.dll" "$root/bin/windows/x86_64/"
python3 "$root/tools/windows/stage_runtime.py" "$root/bin/windows/x86_64" "$LLVM_MINGW_ROOT"
printf 'Native candidate built in %s; Windows runtime verification still required.\n' "$work"
