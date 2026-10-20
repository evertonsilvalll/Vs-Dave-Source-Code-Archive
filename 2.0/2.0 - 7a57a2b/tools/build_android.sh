#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ANDROID_SDK:?Set ANDROID_SDK to the Android SDK directory}"
: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to NDK 21.4.7075529}"
: "${JAVA_HOME:?Set JAVA_HOME to JDK 11}"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SETUP=true
export HXCPP_COMPILE_THREADS="${HXCPP_COMPILE_THREADS:-2}"
python3 tools/prepare_android_assets.py
# Debug signing produces an installable APK without distributing a private release key.
haxelib run lime build android -debug "$@"
