#!/usr/bin/env bash
# Build the signed AAB for Google Play (Jelly Cube 3D).
#
#   STAGE=release ./tools/build_android.sh   # signed bundleRelease AAB
#   STAGE=debug   ./tools/build_android.sh   # CI dry run: assembleDebug
#
# Flow: Cocos Creator CLI generates the Gradle project from
# tools/build-config-android.json, gradle.properties gets target SDK / ABI /
# release signing keys, the manifest gets portrait locked + the AdMob
# APPLICATION_ID, bridge Java classes are copied in and hooked into
# AppActivity, and versions are injected through AGP's android.injected.*
# properties. Signing values come from release.env (git-ignored).
#
# Needs: Cocos Creator 3.8.6 (COCOS env) and a JDK 17+ with the Android SDK.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT/release.env" ]]; then
	# shellcheck disable=SC1091
	source "$ROOT/release.env"
fi
STAGE="${STAGE:-release}"
TARGET_SDK="${TARGET_SDK:-36}"
MIN_SDK="${MIN_SDK:-24}"
COMPILE_SDK="${COMPILE_SDK:-36}"
APP_ABI="${APP_ABI:-arm64-v8a}"
APP_NAME="${APP_NAME:-jellycube3d}"
DISPLAY_NAME="${DISPLAY_NAME:-Jelly Cube 3D}"
PACKAGE_ID="${PACKAGE_ID:-tech.zhongbei.jellycube3d}"
ADMOB_APP_ID="${ADMOB_APP_ID:-ca-app-pub-2271052258925299~2443463295}"
KEY_PASS="${KEY_PASS:-${KEYSTORE_PASS:-}}"

eval "$(python3 "$ROOT/tools/set_versions.py" get)"
VERSION="${VERSION:-$version}"
BUILD="${BUILD:-$build}"
BUILD_DIR="$ROOT/build-android"
PROJ_DIR="$BUILD_DIR/android/proj"
OUT_DIR="$ROOT/export/android"

find_cocos() {
	for candidate in \
		"${COCOS:-}" \
		"/Applications/Cocos/Creator/3.8.6/CocosCreator.app/Contents/MacOS/CocosCreator" \
		"/Applications/Cocos/Creator/3.8.4/CocosCreator.app/Contents/MacOS/CocosCreator" \
		"$HOME/Applications/Cocos/Creator/3.8.6/CocosCreator.app/Contents/MacOS/CocosCreator"; do
		[[ -n "$candidate" && -x "$candidate" ]] && { echo "$candidate"; return; }
	done
}

CC_BIN="$(find_cocos || true)"
if [[ -z "$CC_BIN" ]]; then
	echo "Cocos Creator 3.8.x not found. Set COCOS=/path/to/CocosCreator binary." >&2
	exit 1
fi

# Cocos 3.8.6 engine headers predate clang 17+, which made the argument-less
# `this->template fn()` form a hard error. Upstream fixed it in 3.8.7; patch
# the installed editor's copy in place. Idempotent.
patch_engine_headers() {
	local header
	header="$(dirname "$(dirname "$CC_BIN")")/Resources/resources/3d/engine/native/cocos/core/event/EventTarget.h"
	if [[ -f "$header" ]] && grep -q -- '->template addEventListener(' "$header"; then
		sed -i.bak 's/->template addEventListener(/->addEventListener(/g' "$header" \
			&& rm -f "$header.bak"
		echo "patched engine header for new clang: $header"
	fi
}
patch_engine_headers

echo "== resolve Android SDK/NDK for Cocos"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
# Cocos 3.8.x supports NDK up to r27: r28's libc++ dropped
# std::char_traits<unsigned char>, which the engine bindings still use.
ANDROID_NDK="${ANDROID_NDK:-$(find "$ANDROID_SDK/ndk" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | awk -F/ '$NF + 0 <= 27.99' | tail -1 || true)}"
if [[ -z "$ANDROID_NDK" ]]; then
	ANDROID_NDK="$(find "$ANDROID_SDK/ndk" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1 || true)"
	[[ -n "$ANDROID_NDK" ]] && echo "::warning::only NDK r28+ found; Cocos 3.8.x supports up to r27 — build may fail"
fi
if [[ ! -d "$ANDROID_SDK" ]]; then
	echo "Android SDK not found at $ANDROID_SDK (set ANDROID_HOME)" >&2
	exit 1
fi
if [[ -z "$ANDROID_NDK" ]]; then
	echo "No Android NDK under $ANDROID_SDK/ndk" >&2
	exit 1
fi
echo "sdk: $ANDROID_SDK"
echo "ndk: $ANDROID_NDK"
RESOLVED="$ROOT/.tmp/build-config-android.json"
mkdir -p "$ROOT/.tmp"
python3 - "$ROOT/tools/build-config-android.json" "$RESOLVED" \
	"$ANDROID_SDK" "$ANDROID_NDK" "$ROOT" <<'PY'
import json, os, sys
src, dst, sdk, ndk, root = sys.argv[1:]
with open(src) as f:
    cfg = json.load(f)
splash = cfg.get('splashScreen', {}).get('logo', {})
if splash.get('image') and not os.path.isabs(splash['image']):
    splash['image'] = os.path.join(root, splash['image'])
android = cfg.setdefault('packages', {}).setdefault('android', {})
android['sdkPath'] = sdk
android['ndkPath'] = ndk
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PY

echo "== Cocos CLI build -> Gradle project"
rm -rf "$BUILD_DIR"
# Exit code 36 is Cocos' documented CLI-build success; 32 invalid parameters,
# 34 build error. One line only: a newline inside --build silently no-ops.
set +e
"$CC_BIN" --project "$ROOT" --build "configPath=$RESOLVED"
rc=$?
set -e
if [[ $rc != 36 && $rc != 0 ]]; then
	echo "Cocos CLI build failed with exit code $rc (36=ok, 32=bad params, 34=build error)" >&2
	exit 1
fi
if [[ ! -d "$PROJ_DIR" ]]; then
	echo "No Gradle project at $PROJ_DIR" >&2
	exit 1
fi
echo "project: $PROJ_DIR"

# The engine template pins AGP 8.0.2, whose bundled aapt2 cannot parse the
# resource tables of SDK 35/36 platforms ("RES_TABLE_TYPE_TYPE entry offsets
# overlap"). AGP 8.7.3 handles compileSdk 35 — required by play-services-ads 24.
sed -i.bak "s/classpath 'com.android.tools.build:gradle:8.0.2'/classpath 'com.android.tools.build:gradle:8.13.0'/" \
	"$PROJ_DIR/build.gradle" && rm -f "$PROJ_DIR/build.gradle.bak"
echo "AGP: 8.13.0"

GRADLE_PROPS="$PROJ_DIR/gradle.properties"
touch "$GRADLE_PROPS"
set_prop() {
	# | delimiter: keystore paths contain / and would break s///
	if grep -q "^$1=" "$GRADLE_PROPS"; then
		sed -i.bak "s|^$1=.*|$1=$2|" "$GRADLE_PROPS" && rm -f "$GRADLE_PROPS.bak"
	else
		printf '%s=%s\n' "$1" "$2" >> "$GRADLE_PROPS"
	fi
}

echo "== patch gradle.properties / manifest"
set_prop PROP_TARGET_SDK_VERSION "$TARGET_SDK"
set_prop PROP_MIN_SDK_VERSION "$MIN_SDK"
set_prop PROP_APP_ABI "$APP_ABI"
# play-services-ads 24.x requires compileSdk 35.
set_prop PROP_COMPILE_SDK_VERSION "$COMPILE_SDK"
# Cocos template pins Gradle 8.0.2; AGP 8.7 needs Gradle 8.9.
if [[ -f "$PROJ_DIR/gradle/wrapper/gradle-wrapper.properties" ]]; then
	sed -i.bak 's|gradle-8\.0\.2-bin.zip|gradle-8.13-bin.zip|' "$PROJ_DIR/gradle/wrapper/gradle-wrapper.properties" \
		&& rm -f "$PROJ_DIR/gradle/wrapper/gradle-wrapper.properties.bak"
fi

if [[ "$STAGE" == "release" ]]; then
	if [[ -z "${KEYSTORE:-}" || -z "${KEYSTORE_PASS:-}" || -z "${KEYSTORE_USER:-}" ]]; then
		echo "Signing not configured: set KEYSTORE / KEYSTORE_PASS / KEYSTORE_USER" >&2
		exit 1
	fi
	set_prop RELEASE_STORE_FILE "$KEYSTORE"
	set_prop RELEASE_STORE_PASSWORD "$KEYSTORE_PASS"
	set_prop RELEASE_KEY_ALIAS "$KEYSTORE_USER"
	set_prop RELEASE_KEY_PASSWORD "$KEY_PASS"
fi

NATIVE_DIR="$(sed -n 's/^NATIVE_DIR=//p' "$GRADLE_PROPS" | head -1)"
MAIN_MANIFEST=""
for candidate in "$NATIVE_DIR/app/AndroidManifest.xml" "$PROJ_DIR/app/AndroidManifest.xml"; do
	[[ -n "$candidate" && -f "$candidate" ]] && { MAIN_MANIFEST="$candidate"; break; }
done
if [[ -z "$MAIN_MANIFEST" ]]; then
	echo "app AndroidManifest.xml not found (NATIVE_DIR=$NATIVE_DIR)" >&2
	exit 1
fi

echo "== AdMob + bridge integration"
# 1. Copy the bridge Java classes (package com.jellycube3d.bridge) into the
#    generated app module — Cocos regenerates the project on every build, so
#    this copy is repeated (idempotent) each time.
JAVA_DIR="$NATIVE_DIR/app/src/main/java/com/jellycube3d/bridge"
mkdir -p "$JAVA_DIR"
cp "$ROOT/native/android/AdMobBridge.java" "$ROOT/native/android/HapticsBridge.java" "$JAVA_DIR/"

# 2. Inject the AdMob APPLICATION_ID meta-data into <application>.
if ! grep -q "com.google.android.gms.ads.APPLICATION_ID" "$MAIN_MANIFEST"; then
	META_LINE="        <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$ADMOB_APP_ID\" />"
	awk -v line="$META_LINE" 'BEGIN{done=0} /<application/{print; if(!done){print line; done=1; next} next} {print}' \
		"$MAIN_MANIFEST" > "$MAIN_MANIFEST.tmp" && mv "$MAIN_MANIFEST.tmp" "$MAIN_MANIFEST"
	echo "manifest: AdMob APPLICATION_ID injected"
fi

# 2b. Set user-facing app_name in res/values/strings.xml (Cocos defaults to build name "jellycube3d").
STRINGS_XML="$PROJ_DIR/res/values/strings.xml"
if [[ -f "$STRINGS_XML" ]]; then
	python3 - "$STRINGS_XML" "$DISPLAY_NAME" <<'PY'
import re, sys
p, name = sys.argv[1], sys.argv[2]
src = open(p).read()
dst = re.sub(
    r'(<string\s+name="app_name"[^>]*>)[^<]*(</string>)',
    rf'\g<1>{name}\g<2>',
    src,
)
open(p, "w").write(dst)
PY
	echo "strings.xml: app_name set to '$DISPLAY_NAME'"
fi

# 2c. Copy pre-generated Android launcher + Adaptive Icon (mipmap-anydpi-v26) into res/.
if [[ -d "$ROOT/native/android/res" ]]; then
	cp -R "$ROOT/native/android/res/"* "$NATIVE_DIR/res/"
	echo "res/mipmap-* & adaptive-icon (mipmap-anydpi-v26) synced from native/android/res"
fi

# 3. Patch app/build.gradle and CMakeLists.txt (AdMob, 16KB page size, R8, AndroidX).
APP_GRADLE="$NATIVE_DIR/app/build.gradle"
if [[ ! -f "$APP_GRADLE" ]]; then
	echo "app/build.gradle not found at $APP_GRADLE" >&2
	exit 1
fi
ANDROID_CMAKE="$NATIVE_DIR/CMakeLists.txt"
python3 - "$APP_GRADLE" "$ANDROID_CMAKE" <<'PY'
import re, sys

gradle_path, cmake_path = sys.argv[1], sys.argv[2]
src = open(gradle_path).read()

# 3a. 16 KB page size: CMake flexible page size flag + uncompressed jniLibs packaging
if "ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON" not in src:
    src = src.replace(
        '"-DANDROID_ARM_NEON=TRUE"',
        '"-DANDROID_ARM_NEON=TRUE", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"',
    )
import shutil
if shutil.which("ccache") and "CMAKE_CXX_COMPILER_LAUNCHER=ccache" not in src:
    src = src.replace(
        '"-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"',
        '"-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON", "-DCMAKE_C_COMPILER_LAUNCHER=ccache", "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"',
    )
if "useLegacyPackaging = false" not in src and "    sourceSets.main {" in src:
    src = src.replace(
        "    sourceSets.main {",
        "    packaging {\n        jniLibs {\n            useLegacyPackaging = false\n        }\n    }\n\n    sourceSets.main {",
        1,
    )

# 3b. Enable R8 minification + resource shrinking for release builds
src = re.sub(r'(\brelease\s*\{[\s\S]*?\bminifyEnabled\s+)false\b', r'\1true', src, count=1)
if "shrinkResources true" not in src:
    src = re.sub(
        r'(\bminifyEnabled\s+true\b)',
        r'\1\n            shrinkResources true',
        src,
        count=1,
    )
src = src.replace("proguard-android.txt", "proguard-android-optimize.txt")

# 3c. Pin modern AndroidX fragment/activity & play-services-ads
if "androidx.fragment:fragment:" not in src:
    deps_inject = (
        "dependencies {\n"
        "    implementation 'androidx.fragment:fragment:1.8.5'\n"
        "    implementation 'androidx.activity:activity:1.9.3'\n"
    )
    src = src.replace("dependencies {\n", deps_inject, 1)

if "com.google.android.gms:play-services-ads" not in src:
    src = src.replace(
        "dependencies {\n",
        "dependencies {\n    implementation 'com.google.android.gms:play-services-ads:24.4.0'\n",
        1,
    )
else:
    src = re.sub(
        r"com\.google\.android\.gms:play-services-ads:[0-9.]+",
        "com.google.android.gms:play-services-ads:24.4.0",
        src,
    )

if "resolutionStrategy" not in src and "\ndependencies {" in src:
    src = src.replace(
        "\ndependencies {",
        "\nconfigurations.all {\n    resolutionStrategy {\n"
        "        force 'androidx.fragment:fragment:1.8.5'\n"
        "        force 'androidx.activity:activity:1.9.3'\n"
        "    }\n}\n\ndependencies {",
        1,
    )

open(gradle_path, "w").write(src)

# 3d. Linker 16 KB ELF alignment in CMakeLists.txt
if cmake_path and "max-page-size=16384" not in open(cmake_path).read():
    cm = open(cmake_path).read()
    cm = cm.replace(
        "add_library(${CC_LIB_NAME} SHARED ${CC_ALL_SOURCES})",
        'add_library(${CC_LIB_NAME} SHARED ${CC_ALL_SOURCES})\ntarget_link_options(${CC_LIB_NAME} PRIVATE "-Wl,-z,max-page-size=16384")',
        1,
    )
    open(cmake_path, "w").write(cm)
PY
echo "app/build.gradle & CMakeLists.txt: 16KB page size, R8, AndroidX, play-services-ads patched"

# AGP 8.7 cross-checks android.ndkVersion against android.ndkPath; the
# generated template only declares ndkPath, so AGP falls back to its default
# NDK version and the two disagree. Declare both explicitly.
NDK_VERSION="$(basename "$ANDROID_NDK")"
set_prop PROP_NDK_VERSION "$NDK_VERSION"
sed -i.bak "s|ndkPath PROP_NDK_PATH|ndkPath PROP_NDK_PATH\n    ndkVersion PROP_NDK_VERSION|" "$APP_GRADLE" \
	&& rm -f "$APP_GRADLE.bak"
echo "app/build.gradle: ndkVersion $NDK_VERSION"

# 4. Hook the bridges into AppActivity.onCreate.
APP_ACTIVITY="$(find "$NATIVE_DIR/app/src" -name "AppActivity.java" -print -quit)"
if [[ -z "$APP_ACTIVITY" ]]; then
	echo "AppActivity.java not found under $NATIVE_DIR/app/src" >&2
	exit 1
fi
if ! grep -q "AdMobBridge.init" "$APP_ACTIVITY"; then
	python3 - "$APP_ACTIVITY" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
hook = ("        com.jellycube3d.bridge.AdMobBridge.init(this);\n"
        "        com.jellycube3d.bridge.HapticsBridge.init(this);\n")
if "super.onCreate(" in src:
    # insert right after the existing super.onCreate(savedInstanceState); line
    lines = src.splitlines(keepends=True)
    out = []
    for line in lines:
        out.append(line)
        if "super.onCreate(" in line and "AdMobBridge.init" not in src:
            out.append(hook)
    open(p, "w").write("".join(out))
else:
    raise SystemExit("no super.onCreate( found in " + p + " — wire bridges manually")
PY
	echo "AppActivity: bridge init hooked"
fi

# 5. Version code/name in the generated defaultConfig (regenerated each build).
# BSD sed has no \+ — use [0-9][0-9]* so the code also patches on macOS.
sed -i.bak "s/versionCode [0-9][0-9]*/versionCode $BUILD/" "$APP_GRADLE"
sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$VERSION\"/" "$APP_GRADLE"
rm -f "$APP_GRADLE.bak"
echo "app/build.gradle: version $VERSION ($BUILD)"

# 6. Portrait lock (Jelly Cube 3D is portrait-only).
if grep -q 'android:screenOrientation=' "$MAIN_MANIFEST"; then
	sed -i.bak 's/android:screenOrientation="[^"]*"/android:screenOrientation="portrait"/' \
		"$MAIN_MANIFEST" && rm -f "$MAIN_MANIFEST.bak"
	echo "manifest: portrait locked"
else
	sed -i.bak "s|android:label=\"[^\"]*\"|&\n            android:screenOrientation=\"portrait\"|" "$MAIN_MANIFEST" \
		&& rm -f "$MAIN_MANIFEST.bak" && echo "manifest: portrait attribute added"
fi

# The app has no purchases. The :libcocos engine module (and its bundled APK
# expansion zip classes) re-introduces the Play Billing permission on every
# build, which makes Google flag the bundle as an AIDL-era billing app and
# block the upload. Force-remove it via the manifest merger.
if ! grep -q "xmlns:tools" "$MAIN_MANIFEST"; then
	sed -i.bak 's|<manifest |<manifest xmlns:tools="http://schemas.android.com/tools" |' \
		"$MAIN_MANIFEST" && rm -f "$MAIN_MANIFEST.bak"
fi
if ! grep -q 'android:name="com.android.vending.BILLING" tools:node="remove"' "$MAIN_MANIFEST"; then
	sed -i.bak '/com.android.vending.BILLING/d' "$MAIN_MANIFEST" && rm -f "$MAIN_MANIFEST.bak"
	sed -i.bak 's|<application|    <uses-permission android:name="com.android.vending.BILLING" tools:node="remove" />\n    <application|' \
		"$MAIN_MANIFEST" && rm -f "$MAIN_MANIFEST.bak"
	echo "manifest: BILLING force-removed (tools:node=remove)"
fi

# Same for the advertising ID: the Play Console data-safety declaration says
# the app does not use it, and that web form is not updated in this release.
# Removing AD_ID means AdMob serves non-personalized ads on Android 13+.
if ! grep -q 'com.google.android.gms.permission.AD_ID" tools:node="remove"' "$MAIN_MANIFEST"; then
	sed -i.bak 's|<application|    <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />\n    <application|' \
		"$MAIN_MANIFEST" && rm -f "$MAIN_MANIFEST.bak"
	echo "manifest: AD_ID force-removed (tools:node=remove)"
fi

GRADLE="$PROJ_DIR/gradlew"
if [[ ! -x "$GRADLE" ]]; then
	GRADLE="gradle"
	echo "no gradlew wrapper in $PROJ_DIR, using system gradle"
fi

# Gradle 8.x cannot run on very new JDKs; prefer a 17/21 toolchain.
for candidate in \
	/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
	/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home; do
	if [[ -x "$candidate/bin/java" ]]; then
		export JAVA_HOME="$candidate"
		break
	fi
done
echo "JAVA_HOME: ${JAVA_HOME:-<ambient>}"

echo "== gradle $STAGE build"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
if [[ "$STAGE" == "debug" ]]; then
	(cd "$PROJ_DIR" && "$GRADLE" assembleDebug --no-daemon)
	APK="$(find "$PROJ_DIR" -path '*/outputs/apk/debug/*.apk' -print -quit)"
	if [[ -z "$APK" ]]; then
		echo "assembleDebug produced no APK" >&2
		exit 1
	fi
	cp "$APK" "$OUT_DIR/$APP_NAME-debug.apk"
	echo
	echo "Debug APK: $OUT_DIR/$APP_NAME-debug.apk (dry run OK, no signing attempted)"
	exit 0
fi

(cd "$PROJ_DIR" && "$GRADLE" bundleRelease --no-daemon \
	-Pandroid.injected.version.code="$BUILD" \
	-Pandroid.injected.version.name="$VERSION" \
	-Pandroid.injected.signing.store.file="$KEYSTORE" \
	-Pandroid.injected.signing.store.password="$KEYSTORE_PASS" \
	-Pandroid.injected.signing.key.alias="$KEYSTORE_USER" \
	-Pandroid.injected.signing.key.password="$KEY_PASS")

AAB="$(find "$PROJ_DIR" -path '*/outputs/bundle/release/*.aab' -print -quit)"
if [[ -z "$AAB" ]]; then
	echo "bundleRelease produced no AAB" >&2
	exit 1
fi
cp "$AAB" "$OUT_DIR/$APP_NAME-release.aab"

echo "== verify versionCode"
AAPT2="$(find "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/nonexistent}}" \
	-build-tools -name aapt2 -type f -print 2>/dev/null | sort -V | tail -1 || true)"
if [[ -n "$AAPT2" ]]; then
	CODE="$("$AAPT2" dump badging "$OUT_DIR/$APP_NAME-release.aab" 2>/dev/null \
		| head -1 | sed -n 's/.*versionCode=.\([0-9]*\).*/\1/p')"
	if [[ "$CODE" == "$BUILD" ]]; then
		echo "versionCode $CODE matches build $BUILD"
	else
		echo "versionCode mismatch: AAB says '$CODE', expected '$BUILD'" >&2
		exit 1
	fi
else
	echo "aapt2 not found; skipping versionCode check"
fi

echo
echo "AAB: $OUT_DIR/$APP_NAME-release.aab (version $VERSION build $BUILD)"
