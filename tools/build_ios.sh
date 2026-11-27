#!/usr/bin/env bash
# Build an App Store IPA for Jelly Cube 3D.
#
#   STAGE=ipa  ./tools/build_ios.sh   # full: Cocos -> Pods -> Xcode -> archive -> IPA
#   STAGE=sim  ./tools/build_ios.sh   # CI dry run: unsigned compile
#   STAGE=xcode ./tools/build_ios.sh  # stop after the Xcode project exists
#
# Flow: Cocos Creator CLI generates the Xcode project from
# tools/build-config-ios.json. On the first run the editor also materialises
# the native/engine/ios template dir; this script then copies the AdMob /
# Haptics bridges into it, hooks [AdMobBridge preloadAds] into AppDelegate,
# and rebuilds once so the new sources are globbed into the project.
# GoogleMobileAds is pulled in via CocoaPods, the archived Info.plist gets
# the GADApplicationIdentifier / ATT strings / portrait orientation, and
# -exportArchive re-signs with the distribution identity. Finally
# tools/ios/PrivacyInfo.xcprivacy is injected into the .app and re-signed.
#
# Needs: Cocos Creator 3.8.6 (COCOS env), Xcode, CocoaPods, an Apple
# Distribution certificate for the team, and an ASC API key for
# -allowProvisioningUpdates. release.env (git-ignored) carries the secrets.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT/release.env" ]]; then
	# shellcheck disable=SC1091
	source "$ROOT/release.env"
fi
STAGE="${STAGE:-ipa}"
TEAM_ID="${TEAM_ID:-2VA9TC6SG4}"
BUNDLE_ID="${BUNDLE_ID:-tech.zhongbei.jellycube3d}"
APP_NAME="${APP_NAME:-jellycube3d}"
DISPLAY_NAME="${DISPLAY_NAME:-Jelly Cube 3D}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Apple Distribution: Zhenwei Ruan (2VA9TC6SG4)}"
ASC_KEY_PATH="${ASC_KEY_PATH:-/Users/echo/workspace/keys/AuthKey_3A864HP66K.p8}"
ASC_KEY_ID="${ASC_KEY_ID:-3A864HP66K}"
ASC_ISSUER="${ASC_ISSUER:-3c721bed-bf99-4f67-891f-5ae3b78bc7ac}"
ADMOB_APP_ID="${ADMOB_APP_ID:-ca-app-pub-2271052258925299~4315636529}"
PRIVACY="$ROOT/tools/ios/PrivacyInfo.xcprivacy"
# Cocos 3.8.6 defaults to iOS 12.0; modern Xcode (26+) refuses anything
# below 15.0.
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-15.0}"
# New clang (Xcode 26+) hard-errors on patterns Cocos 3.8.6's vendored
# headers still use. Downgrade those diagnostics; real breakage still fails.
IOS_EXTRA_CXXFLAGS='$(inherited) -Wno-error=invalid-specialization -Wno-error=enum-constexpr-conversion -Wno-error=deprecated-declarations -Wno-error=deprecated-non-prototype -Wno-deprecated-builtins -Wno-nontrivial-memcall'
# GoogleMobileAds is Swift-built but statically linked into an ObjC-only app:
# the linker needs the Swift static compatibility libs explicitly on the path.
SWIFT_COMPAT_DIR="$(dirname "$(find "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift" \
	-path '*iphoneos/libswiftCompatibility51.a' -print -quit 2>/dev/null)" 2>/dev/null || true)"
if [[ -z "$SWIFT_COMPAT_DIR" || ! -d "$SWIFT_COMPAT_DIR" ]]; then
	SWIFT_COMPAT_DIR="$(dirname "$(find "$(xcode-select -p)" \
		-name 'libswiftCompatibility51.a' -print -quit 2>/dev/null)" 2>/dev/null || true)"
fi
if [[ -z "$SWIFT_COMPAT_DIR" || ! -f "$SWIFT_COMPAT_DIR/libswiftCompatibility51.a" ]]; then
	SWIFT_COMPAT_DIR="$(dirname "$(find /var/run/com.apple.security.cryptexd \
		-name 'libswiftCompatibility51.a' -print -quit 2>/dev/null)" 2>/dev/null || true)"
fi
if [[ -n "$SWIFT_COMPAT_DIR" && -f "$SWIFT_COMPAT_DIR/libswiftCompatibility51.a" ]]; then
	echo "swift compat libs: $SWIFT_COMPAT_DIR"
	IOS_EXTRA_LDFLAGS="\$(inherited) -L$SWIFT_COMPAT_DIR -lswiftCompatibility51 -lswiftCompatibility56 -lswiftCompatibilityConcurrency"
else
	echo "::warning::Swift static compatibility libs not found; relying on toolchain autolink"
	IOS_EXTRA_LDFLAGS='$(inherited)'
fi

eval "$(python3 "$ROOT/tools/set_versions.py" get)"
VERSION="${VERSION:-$version}"
BUILD="${BUILD:-$build}"
BUILD_DIR="$ROOT/build-ios-native"
PROJ_DIR="$BUILD_DIR/ios/proj"
ARCHIVE="$ROOT/export/ios/$APP_NAME.xcarchive"
EXPORT_DIR="$ROOT/export/ios/export"
TEMPLATE_IOS="$ROOT/native/engine/ios"

find_cocos() {
	for candidate in \
		"${COCOS:-}" \
		"/Applications/Cocos/Creator/3.8.6/CocosCreator.app/Contents/MacOS/CocosCreator" \
		"/Applications/Cocos/Creator/3.8.4/CocosCreator.app/Contents/MacOS/CocosCreator" \
		"$HOME/Applications/Cocos/Creator/3.8.6/CocosCreator.app/Contents/MacOS/CocosCreator"; do
		[[ -n "$candidate" && -x "$candidate" ]] && { echo "$candidate"; return; }
	done
}

cocos_build() {
	echo "== Cocos CLI build -> Xcode project"
	rm -rf "$BUILD_DIR"
	set +e
	"$CC_BIN" --project "$ROOT" --build "configPath=$ROOT/.tmp/build-config-ios.json"
	rc=$?
	set -e
	if [[ $rc != 36 && $rc != 0 ]]; then
		echo "Cocos CLI build failed with exit code $rc (36=ok, 32=bad params, 34=build error)" >&2
		exit 1
	fi
}

CC_BIN="$(find_cocos || true)"
if [[ -z "$CC_BIN" ]]; then
	echo "Cocos Creator 3.8.x not found. Set COCOS=/path/to/CocosCreator binary." >&2
	exit 1
fi

# Cocos 3.8.6 engine headers predate clang 17+; patch the installed editor's
# copy in place. Idempotent.
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

# Some vendored .a libraries have 64-bit mach-o members that are not 8-byte
# aligned; the new linker drops those members outright. Repack in place.
EDITOR_RES="$(dirname "$(dirname "$CC_BIN")")/Resources/resources/3d/engine/native/external"
LIB_DIRS=()
for d in ios/libs ios-m1-simulator/libs mac/libs; do
	[[ -d "$EDITOR_RES/$d" ]] && LIB_DIRS+=("$EDITOR_RES/$d")
done
if [[ ${#LIB_DIRS[@]} -gt 0 ]]; then
	python3 "$ROOT/tools/repack_libs.py" "${LIB_DIRS[@]}"
fi

if [[ "$STAGE" == "ipa" && ! -f "$ASC_KEY_PATH" ]]; then
	echo "App Store Connect key not found at: $ASC_KEY_PATH" >&2
	exit 1
fi

mkdir -p "$ROOT/.tmp"
RESOLVED="$ROOT/.tmp/build-config-ios.json"
python3 - "$ROOT/tools/build-config-ios.json" "$RESOLVED" "$ROOT" <<'PY'
import json, os, sys
src, dst, root = sys.argv[1:]
with open(src) as f:
    cfg = json.load(f)
splash = cfg.get('splashScreen', {}).get('logo', {})
if splash.get('image') and not os.path.isabs(splash['image']):
    splash['image'] = os.path.join(root, splash['image'])
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PY

# -- First Cocos pass: creates native/engine/ios on the very first run.
if [[ ! -d "$TEMPLATE_IOS" ]]; then
	cocos_build
fi
if [[ ! -d "$TEMPLATE_IOS" ]]; then
	echo "native/engine/ios still missing after Cocos build — run once via the editor GUI" >&2
	exit 1
fi

# -- Bridge integration (persistent template edits, idempotent).
# apple.cmake lists template sources explicitly (no glob), so the bridges
# must also be appended to the template CMakeLists.txt.
CML="$TEMPLATE_IOS/CMakeLists.txt"
if [[ -f "$CML" ]] && ! grep -q "AdMobBridge.mm" "$CML"; then
	python3 - "$CML" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
anchor = 'include(${CC_PROJECT_DIR}/../common/CMakeLists.txt)'
add = (anchor + "\n\n# AdMob / haptics bridges (added by tools/build_ios.sh)\n"
       "list(APPEND CC_PROJ_SOURCES\n"
       "    ${CC_PROJECT_DIR}/AdMobBridge.mm\n"
       "    ${CC_PROJECT_DIR}/HapticsBridge.mm\n)\n")
open(p, 'w').write(src.replace(anchor, add, 1))
PY
	echo "CMakeLists: bridge sources appended"
fi

if [[ -f "$CML" ]] && ! grep -q "SceneDelegate.mm" "$CML"; then
	python3 - "$CML" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
anchor = '    ${CC_PROJECT_DIR}/HapticsBridge.mm\n)'
add = '    ${CC_PROJECT_DIR}/HapticsBridge.mm\n    ${CC_PROJECT_DIR}/SceneDelegate.mm\n)'
if anchor not in src:
    raise SystemExit('bridge sources block not found in ' + p)
open(p, 'w').write(src.replace(anchor, add, 1))
PY
	echo "CMakeLists: SceneDelegate appended"
fi
if [[ -f "$CML" ]] && ! grep -q "AppTrackingTransparency" "$CML"; then
	python3 - "$CML" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
anchor = 'cc_ios_after_target(${EXECUTABLE_NAME})'
add = (anchor + "\n\nif(IOS)\n"
       "    target_link_libraries(${EXECUTABLE_NAME} \"-framework AppTrackingTransparency\")\nendif()\n")
open(p, 'w').write(src.replace(anchor, add, 1))
PY
	echo "CMakeLists: ATT framework linked"
fi
# Always refresh the bridge sources from native/ios. Gating this copy on
# "file missing" is what let 2.0.0 ship a stale AdMobBridge (ATT still called,
# Info.plist had no usage string) even after native/ios was fixed.
echo "== inject AdMob/Haptics bridges into native/engine/ios"
cp "$ROOT/native/ios/AdMobBridge.mm" "$ROOT/native/ios/HapticsBridge.mm" \
	"$ROOT/native/ios/AppDelegate.mm" "$ROOT/native/ios/SceneDelegate.mm" "$TEMPLATE_IOS/"

# Class declarations so AppDelegate.mm can call the bridges. Signatures must
# match AdMobBridge.mm exactly.
cat > "$TEMPLATE_IOS/AdMobBridge.h" <<'H'
#import <Foundation/Foundation.h>

@interface AdMobBridge : NSObject
+ (instancetype)shared;
+ (NSString *)launchValue:(NSString *)key;
+ (void)preloadAds;
+ (void)showRewardedAd:(NSString *)placement callback:(NSString *)cbName;
+ (void)showInterstitialAd:(NSString *)placement;
+ (void)setBannerVisible:(NSString *)visibleFlag;
+ (void)requestReview:(NSString *)unused;
@end
H


# Shared plist helpers: the scene template and the archived app must carry the
# same keys, or the iOS 26+ scene enforcement traps at launch.
plist_set() {
	local plist="$1" key="$2" value="$3"
	/usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" 2>/dev/null \
		|| /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
}

apply_scene_manifest() {
	local plist="$1"
	/usr/libexec/PlistBuddy -c "Delete :UIApplicationSceneManifest" "$plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy \
		-c "Add :UIApplicationSceneManifest dict" \
		-c "Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false" \
		-c "Add :UIApplicationSceneManifest:UISceneConfigurations dict" \
		-c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication array" \
		-c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0 dict" \
		-c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneConfigurationName string Default Configuration" \
		-c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName string SceneDelegate" \
		"$plist"
}

apply_portrait_fullscreen() {
	local plist="$1"
	/usr/libexec/PlistBuddy -c "Delete :UISupportedInterfaceOrientations" "$plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations array" \
		-c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$plist"
	/usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen true" "$plist" 2>/dev/null \
		|| /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool true" "$plist"
}

APP_DELEGATE="$TEMPLATE_IOS/AppDelegate.mm"
if grep -q "preloadAds" "$APP_DELEGATE"; then
	echo "AppDelegate: hook already present"
else
	python3 - "$APP_DELEGATE" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
hook = "    [AdMobBridge preloadAds];\n"
if "didFinishLaunchingWithOptions" not in src:
    raise SystemExit("no didFinishLaunching in " + p)
# insert as first statement of didFinishLaunching body
idx = src.index("didFinishLaunchingWithOptions")
idx = src.index("{", idx)
src = src[: idx + 1] + "\n" + hook + src[idx + 1 :]
# declaration import at top (after the first #import block)
lines = src.splitlines(keepends=True)
last_import = 0
for i, line in enumerate(lines):
    if line.startswith("#import"):
        last_import = i
lines.insert(last_import + 1, '#import "AdMobBridge.h"\n')
open(p, "w").write("".join(lines))
PY
	echo "AppDelegate: preloadAds hook added"
fi

# One build is enough now that the bridges are already in the template before
# CMake configures the project.
cocos_build

# The Cocos build rewrites the template (including its default launch image),
# so install the branded launch screen after it, same as the plist patch.
cp "$ROOT/native/ios/LaunchScreenBackground.png" "$TEMPLATE_IOS/LaunchScreenBackground.png"
cp "$ROOT/native/ios/LaunchScreenBackgroundPortrait.png" "$TEMPLATE_IOS/LaunchScreenBackgroundPortrait.png"

# Patch the template after the Cocos build: the editor rewrites
# UISupportedInterfaceOrientations from the project settings, which would
# otherwise leave dev builds landscape (Xcode "Run" bypasses the archive step).
if [[ -f "$TEMPLATE_IOS/Info.plist" ]]; then
	echo "== patch template Info.plist (scene manifest, AdMob, portrait)"
	plist_set "$TEMPLATE_IOS/Info.plist" GADApplicationIdentifier "$ADMOB_APP_ID"
	plist_set "$TEMPLATE_IOS/Info.plist" NSUserTrackingUsageDescription "This identifier will be used to deliver personalized ads to you."
	apply_scene_manifest "$TEMPLATE_IOS/Info.plist"
	apply_portrait_fullscreen "$TEMPLATE_IOS/Info.plist"
fi

if [[ ! -d "$PROJ_DIR" ]]; then
	echo "No Xcode proj at $PROJ_DIR" >&2
	exit 1
fi

# The real app project sits directly under proj/; never pick CMake probe dirs.
XCODEPROJ="$(find -L "$PROJ_DIR" -maxdepth 2 -name '*.xcodeproj' -not -path '*CMakeFiles*' -type d -print -quit)"
if [[ -z "$XCODEPROJ" ]]; then
	echo "No app .xcodeproj under $PROJ_DIR; candidates:" >&2
	find -L "$PROJ_DIR" -name '*.xcodeproj' -type d >&2
	exit 1
fi
echo "project: $XCODEPROJ"

SCHEME="$(xcodebuild -list -json -project "$XCODEPROJ" \
	| python3 -c 'import json,sys; print(json.load(sys.stdin)["project"]["schemes"][0])')"
echo "scheme: $SCHEME"

if [[ "$STAGE" == "xcode" ]]; then
	echo
	echo "STAGE=xcode: Xcode project ready at $PROJ_DIR (no compile attempted)."
	exit 0
fi

echo "== CocoaPods: GoogleMobileAds"
if [[ ! -f "$PROJ_DIR/Podfile" ]]; then
	cat > "$PROJ_DIR/Podfile" <<PODFILE
platform :ios, '$IOS_DEPLOYMENT_TARGET'
target '$SCHEME' do
  pod 'Google-Mobile-Ads-SDK'
end
PODFILE
fi
(cd "$PROJ_DIR" && pod install --repo-update)
WORKSPACE="$(find -L "$PROJ_DIR" -maxdepth 1 -name '*.xcworkspace' -print -quit)"
if [[ -z "$WORKSPACE" ]]; then
	echo "pod install produced no .xcworkspace" >&2
	exit 1
fi

if [[ "$STAGE" == "sim" ]]; then
	echo "== unsigned simulator compile (CI dry run)"
	BUILD_ARGS=(
		-workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release
		-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'
		IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
		OTHER_CPLUSPLUSFLAGS="$IOS_EXTRA_CXXFLAGS"
		OTHER_LDFLAGS="$IOS_EXTRA_LDFLAGS"
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
		PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
	)
	if ! xcodebuild "${BUILD_ARGS[@]}" build; then
		echo "simulator compile failed; retrying as unsigned device build"
		xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release \
			-sdk iphoneos -destination 'generic/platform=iOS' \
			IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
			OTHER_CPLUSPLUSFLAGS="$IOS_EXTRA_CXXFLAGS" \
			OTHER_LDFLAGS="$IOS_EXTRA_LDFLAGS" \
			CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
			PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" build
	fi
	echo
	echo "STAGE=sim: compile OK (no signing attempted)."
	exit 0
fi

# Cocos 3.8 iOS projects are CMake-generated: there is no physical app
# Info.plist in the project, it materialises inside the archive. Patch it
# there — -exportArchive re-signs with the distribution identity afterwards,
# so plist edits between archive and export are legitimate.

echo "== archive (automatic signing + ASC API key)"
SIGNING_ARGS=(
	DEVELOPMENT_TEAM="$TEAM_ID"
	PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
	MARKETING_VERSION="$VERSION"
	CURRENT_PROJECT_VERSION="$BUILD"
	IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
	OTHER_CPLUSPLUSFLAGS="$IOS_EXTRA_CXXFLAGS"
	OTHER_LDFLAGS="$IOS_EXTRA_LDFLAGS"
	GCC_GENERATE_DEBUGGING_SYMBOLS=YES
	-allowProvisioningUpdates
	-authenticationKeyPath "$ASC_KEY_PATH"
	-authenticationKeyID "$ASC_KEY_ID"
	-authenticationKeyIssuerID "$ASC_ISSUER"
	CODE_SIGN_STYLE=Automatic
	CODE_SIGN_IDENTITY="Apple Development"
)
rm -rf "$ARCHIVE"
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" \
	-configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE" \
	"${SIGNING_ARGS[@]}" \
	archive

echo "== patch the archived Info.plist"
APP_DIR="$(find "$ARCHIVE/Products" -maxdepth 3 -name '*.app' -type d -print -quit)"
if [[ -z "$APP_DIR" ]]; then
	echo "No .app inside $ARCHIVE/Products" >&2
	exit 1
fi
INFO_PLIST="$APP_DIR/Info.plist"
pb_set() {
	/usr/libexec/PlistBuddy -c "Set :$1 $2" "$INFO_PLIST" 2>/dev/null \
		|| /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$INFO_PLIST"
}
pb_set ITSAppUsesNonExemptEncryption false
pb_set CFBundleDisplayName "$DISPLAY_NAME"
pb_set CFBundleShortVersionString "$VERSION"
pb_set CFBundleVersion "$BUILD"
pb_set GADApplicationIdentifier "$ADMOB_APP_ID"
apply_scene_manifest "$INFO_PLIST"
# ATT purpose string: required whenever ATTrackingManager is invoked. Missing
# it terminates the app at launch (TCC), which is what 2.0.0 shipped.
pb_set NSUserTrackingUsageDescription "This identifier will be used to deliver personalized ads to you."
# Portrait only, fullscreen: rewrite the orientation array wholesale.
/usr/libexec/PlistBuddy -c "Delete :UISupportedInterfaceOrientations" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen true" "$INFO_PLIST" 2>/dev/null \
	|| /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool true" "$INFO_PLIST"
echo "Info.plist: $INFO_PLIST"

echo "== export App Store IPA"
cat > "$ROOT/export/ios/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>$TEAM_ID</string>
	<key>destination</key><string>export</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
rm -rf "$EXPORT_DIR"
# Xcode copies the dSYMs into the IPA with /usr/bin/rsync -E. When a Homebrew
# rsync shadows the system one, the local server rejects --extended-attributes
# and export dies with "Copy failed"; keep the system rsync first.
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH" \
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$ROOT/export/ios/ExportOptions.plist" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER"

IPA="$(find "$EXPORT_DIR" -name '*.ipa' -print -quit)"
if [[ -z "$IPA" ]]; then
	echo "Export produced no IPA" >&2
	exit 1
fi

echo "== inject PrivacyInfo.xcprivacy, App Store icons; re-sign"
STAGE_DIR="$ROOT/export/ios/ipa-stage"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
unzip -q "$IPA" -d "$STAGE_DIR"
APP_BUNDLE="$(find "$STAGE_DIR" -maxdepth 2 -name '*.app' -type d -print -quit)"
cp "$PRIVACY" "$APP_BUNDLE/PrivacyInfo.xcprivacy"

# Cocos writes accelerometer/opengles-1 into UIRequiredDeviceCapabilities;
# Apple's upload validation rejects accelerometer for visionOS compat.
/usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities:accelerometer" "$APP_BUNDLE/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities:opengles-1" "$APP_BUNDLE/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :UIRequiredDeviceCapabilities:arm64 true" "$APP_BUNDLE/Info.plist" 2>/dev/null || true

# Cocos's asset catalog only carries iPhone icons, so App Store validation
# rejects the upload for missing iPad (152px) / iPad Pro (167px) icons.
# Rebuild Assets.car from the single-size 1024 appiconset via actool.
ICONSET="$ROOT/.tmp/appicon"
mkdir -p "$ICONSET/AppIcon.appiconset" "$ROOT/.tmp/appicon-out"
# NB: no "${X:-...Rubik's...}" here — an apostrophe inside a parameter
# expansion default is a bash parsing trap. Assign the default plainly first.
DEFAULT_ICON="$ROOT/settings/app_icon_1024.png"
ICON_SRC="${ICON_SRC:-$DEFAULT_ICON}"
sips -s format png -z 1024 1024 "$ICON_SRC" --out "$ICONSET/AppIcon.appiconset/icon_1024.png" >/dev/null
cat > "$ICONSET/AppIcon.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
cat > "$ICONSET/Contents.json" <<'JSON'
{ "info" : { "author" : "xcode", "version" : 1 } }
JSON
xcrun actool --compile "$ROOT/.tmp/appicon-out" --app-icon AppIcon \
	--output-partial-info-plist "$ROOT/.tmp/appicon-out/partial.plist" \
	--platform iphoneos --minimum-deployment-target "$IOS_DEPLOYMENT_TARGET" \
	"$ICONSET"
cp "$ROOT/.tmp/appicon-out/Assets.car" "$APP_BUNDLE/Assets.car"
cp "$ROOT/.tmp/appicon-out/"AppIcon*.png "$APP_BUNDLE/" 2>/dev/null || true
# Canonical icon plist from actool (loose-file entries for pre-iOS fallback).
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$APP_BUNDLE/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons~ipad" "$APP_BUNDLE/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons dict" \
	-c "Add :CFBundleIcons:CFBundlePrimaryIcon dict" \
	-c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles array" \
	-c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60" \
	-c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName string AppIcon" \
	-c "Add :CFBundleIcons~ipad dict" \
	-c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon dict" \
	-c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles array" \
	-c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60" \
	-c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:1 string AppIcon76x76" \
	-c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconName string AppIcon" \
	"$APP_BUNDLE/Info.plist"

codesign --force --sign "$SIGNING_IDENTITY" \
	--preserve-metadata=entitlements,requirements,flags "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
FINAL_IPA="$ROOT/export/ios/$APP_NAME-$VERSION.ipa"
# zip updates an existing archive in place, keeping entries that are no longer
# staged (stale JS/scene files survive and break the bundle seal). Start clean.
rm -f "$FINAL_IPA"
(cd "$STAGE_DIR" && zip -qry "$FINAL_IPA" .)
echo "IPA: $FINAL_IPA (version $VERSION build $BUILD)"
