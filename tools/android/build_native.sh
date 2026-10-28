#!/usr/bin/env bash
# Uses an already installed, authorized Android NDK and verified source checkouts.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${ANDROID_NDK_ROOT:?Set the official Android NDK r28b path}"
: "${FSNET_SOURCE_DIR:?Set an external fsnet Git checkout}"
: "${GODOT_CPP_DIR:?Set official godot-cpp 10.0.0-stable checkout}"
: "${LUA_SOURCE_DIR:?Set verified upstream Lua 5.4.7 source directory}"
[[ $(git -C "$GODOT_CPP_DIR" rev-parse HEAD) == 507ed9d840c01a3c5b2a39af8bb4000bfac30bf5 ]]
grep -q 'Pkg.Revision = 28.1.13356709' "$ANDROID_NDK_ROOT/source.properties"
work=${ANDROID_BUILD_DIR:-"$root/build/android"}
mkdir -p "$work/source" "$root/bin/android/arm64-v8a"
git -C "$FSNET_SOURCE_DIR" archive 8e4af0c9b73445d999a9e3593c1429c63bbec882 | tar -x -C "$work/source"
cp "$root/tools/android/OpenSSL.cmake" "$work/source/cmake/OpenSSL.cmake"
export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
common=(-DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release)
cmake -S "$work/source" -B "$work/fsnet" "${common[@]}" -DBUILD_TESTING=OFF -DFSNET_WITH_LUA=OFF -DFSNET_WITH_POSTGRES=OFF
cmake --build "$work/fsnet" --target fsnet --parallel "${BUILD_JOBS:-4}"
cmake -S "$root" -B "$work/amber" "${common[@]}" -DGODOT_CPP_DIR="$GODOT_CPP_DIR" -DLUA_SOURCE_DIR="$LUA_SOURCE_DIR" -DFSNET_SOURCE_DIR="$work/source" -DFSNET_LIBRARY="$work/fsnet/libfsnet.so"
cmake --build "$work/amber" --parallel "${BUILD_JOBS:-4}"
cp "$work/fsnet/libfsnet.so" "$root/bin/android/arm64-v8a/"
llvm-strip --strip-unneeded "$root/bin/android/arm64-v8a/"*.so
printf 'Built arm64-v8a native libraries; APK export and device validation remain separate.\n'
