# Android test build

Baseline: e735b3092371e252ca2a41b47fef40d243cc68c2. This branch adds packaging only; it does not include the Tessa animation experiment.

Use Godot 4.6.3 and its matching official export templates, an installed JDK, Android SDK build tools, and official NDK r28b (28.1.13356709). Accept the Android SDK license only with the user's authorization. No credentials or toolchains belong in Git.

`build_native.sh` uses the pinned fsnet revision from the main README, official godot-cpp 10.0.0-stable and verified Lua 5.4.7 sources. Set `ANDROID_NDK_ROOT`, `FSNET_SOURCE_DIR`, `GODOT_CPP_DIR`, and `LUA_SOURCE_DIR`, then run the script. Its private fsnet source copy uses an Android OpenSSL configuration. Lua and OpenSSL are statically included, while the APK contains libamber.so and libfsnet.so. The official Godot template supplies libc++_shared.so: do not add a second copy through the extension dependency map.

Import the project with Godot, configure the Java/Android SDK paths, and export the `Android Test` preset with `--export-debug`. Supply a local debug keystore through the documented Godot environment variables. Never use release signing secrets for this test build. The package ID is `org.frodosens.amberbridge.test`, arm64-v8a only. The 4.6.3 binary template uses minimum SDK 24 and target SDK 36; the non-Gradle preset intentionally uses template defaults.

Validate the resulting APK with `apksigner verify --verbose --print-certs`, `zipalign -c -P 16 -v 4`, and `python3 tools/android/verify_apk.py PATH.apk` with the NDK llvm-readelf on PATH. The verifier checks architecture, required native libraries, dependency closure, ELF 16 KB segment alignment, duplicate entries, and the shared Lua/second-chapter payload.

Desktop chapter/checkpoint regression checks are useful but do not establish Android device compatibility. Physical device installation, touch controls, graphics, audio, and networking need on-device acceptance. APKs and local signing keys must remain outside the repository.
