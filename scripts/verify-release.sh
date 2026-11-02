#!/usr/bin/env bash
# Verify local artifacts before human store submission. Never uploads.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAILED=0
note() { printf '%s\n' "$*"; }
ok() { printf '  OK  %s\n' "$*"; }
bad() { printf ' FAIL %s\n' "$*"; FAILED=1; }
need() { [[ -e "$1" ]] && ok "$2" || bad "$2 (missing: $1)"; }
AAPT="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/36.0.0/aapt2"
APKSIGNER="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/36.0.0/apksigner"
ZIPALIGN="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/36.0.0/zipalign"
EXPECTED_PACKAGE="tech.zhongbei.jellycube3d"
EXPECTED_LABEL="Jelly Cube 3D"

note "== Repository / secrets =="
if [[ -d .git ]]; then ok "Git repository present"; else bad "Not a Git repository"; fi
for f in release.env android/key.properties; do
  [[ -e "$f" ]] && ok "$f exists locally" || true
done
if find . -path ./build -prune -o -path ./.dart_tool -prune -o -type f \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.mobileprovision' \) -print | grep -q .; then
  bad "Signing material exists in the working tree (should be outside the repo)"
else
  ok "No signing material found in the repository"
fi

note "== Core project =="
need lib/jelly_cube_3d.dart "Dart public entry exists"
need ios/Runner/PrivacyInfo.xcprivacy "iOS app privacy manifest exists"
need docs/PRIVACY.md "Privacy policy exists"
need docs/TERMS.md "Terms exist"
need docs/SUPPORT.md "Support page exists"
need store/apple/icon-1024.png "App Store 1024 icon exists"
need store/google/icon-512.png "Google Play 512 icon exists"
need store/google/feature-graphic-1024x500.png "Google feature graphic exists"

note "== iOS =="
IPA="$(find build/release build/ios/ipa -name '*.ipa' -maxdepth 3 2>/dev/null | head -1 || true)"
if [[ -n "$IPA" ]]; then
  TMP_IPA="$(mktemp -d)"
  if unzip -q "$IPA" -d "$TMP_IPA" 2>/dev/null; then
    APP="$TMP_IPA/Payload/Runner.app"
    plist="$APP/Info.plist"
    [[ "$(plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null)" == "$EXPECTED_PACKAGE" ]] && ok "Bundle ID (IPA)" || bad "IPA bundle ID mismatch"
    [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$plist" 2>/dev/null)" == "false" ]] && ok "Encryption declaration (IPA)" || bad "IPA missing export compliance"
    [[ -f "$APP/PrivacyInfo.xcprivacy" ]] && ok "App privacy manifest in IPA" || bad "App privacy manifest not in IPA"
    CS_OUT="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
    if grep -q 'Authority=Apple Distribution' <<<"$CS_OUT"; then
      ok "Apple Distribution-signed IPA"
    else
      bad "IPA is not Apple Distribution-signed"
    fi
    if [[ -f "$APP/embedded.mobileprovision" ]]; then
      if security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | plutil -extract Entitlements.get-task-allow raw - 2>/dev/null | grep -q '^false$'; then
        ok "App Store provisioning profile (get-task-allow=false)"
      else
        bad "IPA does not use an App Store distribution profile"
      fi
    else
      bad "IPA has no embedded provisioning profile"
    fi
  else
    bad "IPA could not be unpacked"
  fi
  rm -rf "$TMP_IPA"
elif [[ -d build/ios/archive/Runner.xcarchive ]]; then
  APP="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
  plist="$APP/Info.plist"
  [[ "$(plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null)" == "$EXPECTED_PACKAGE" ]] && ok "Bundle ID (archive)" || bad "Bundle ID mismatch"
  [[ "$(plutil -extract CFBundleShortVersionString raw "$plist" 2>/dev/null)" == "1.0.0" ]] && ok "Version 1.0.0" || bad "Version mismatch"
  [[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$plist" 2>/dev/null)" == "false" ]] && ok "Encryption declaration (archive)" || bad "Missing export compliance"
  [[ -f "$APP/PrivacyInfo.xcprivacy" ]] && ok "App privacy manifest (archive)" || bad "App privacy manifest not in archive"
  CS_OUT="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
  if grep -q 'Authority=Apple Distribution' <<<"$CS_OUT"; then
    ok "Apple Distribution-signed archive"
  else
    bad "Archive is not Apple Distribution-signed"
  fi
  bad "IPA missing"
else
  bad "iOS archive missing"
fi

note "== Android =="
APK="build/app/outputs/flutter-apk/app-release.apk"
AAB="build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$APK" && -x "$AAPT" ]]; then
  BAG="$(mktemp)"
  "$AAPT" dump badging "$APK" >"$BAG" 2>/dev/null || true
  grep -q "name='$EXPECTED_PACKAGE'" "$BAG" && ok "Package ID" || bad "Android package mismatch"
  grep -q "application-label:'$EXPECTED_LABEL'" "$BAG" && ok "App label" || bad "Android label mismatch"
  grep -q "targetSdkVersion:'36'" "$BAG" && ok "targetSdk 36" || bad "targetSdk is not 36"
  "$AAPT" dump permissions "$APK" >"$BAG" 2>/dev/null || true
  if grep -q 'android.permission.INTERNET' "$BAG"; then
    if grep -q 'com.android.vending.BILLING' "$BAG"; then
      ok "INTERNET present for Play Billing only (BILLING declared)"
    else
      bad "INTERNET permission present without a billing declaration"
    fi
  else
    ok "No INTERNET permission"
  fi
  "$APKSIGNER" verify --print-certs "$APK" >"$BAG" 2>/dev/null || true
  if grep -q 'CN=Android Debug' "$BAG"; then
    bad "APK is debug-signed"
  else
    ok "APK is not debug-signed"
  fi
  rm -f "$BAG"
  "$ZIPALIGN" -c -P 16 -v 4 "$APK" >/dev/null 2>&1 && ok "16 KB zip alignment" || bad "16 KB zip alignment failed"
else
  bad "Release APK/aapt2 missing"
fi
[[ -f "$AAB" ]] && ok "AAB exists" || bad "AAB missing"

note "== HarmonyOS =="
if [[ -d ohos ]]; then
  ok "ohos/ project exists"
  if grep -q '"ohos.permission.INTERNET"' ohos/entry/src/main/module.json5 2>/dev/null; then
    bad "OHOS INTERNET permission present"
  else
    ok "OHOS INTERNET permission absent"
  fi
  if grep -q '"tablet"' ohos/entry/src/main/module.json5 2>/dev/null; then
    ok "OHOS tablet device type declared"
  else
    bad "OHOS tablet device type missing"
  fi
  HAP_FOUND="$(find build/ohos/hap build/release -name '*.hap' -maxdepth 3 2>/dev/null | head -1 || true)"
  if [[ -n "$HAP_FOUND" ]]; then
    if [[ "$HAP_FOUND" == *unsigned* ]]; then
      bad "HAP is unsigned ($HAP_FOUND)"
    else
      ok "Signed HAP artifact exists"
    fi
  else
    bad "HAP artifact missing"
  fi
else
  bad "ohos/ project missing"
fi

note "== Store assets =="
for f in store/apple/icon-1024.png store/google/icon-512.png store/google/feature-graphic-1024x500.png store/listing-en.md docs/IAP.md ACCOUNTS_AND_SIGNING.md; do
  need "$f" "$f"
done
if python3 tool/check_store_assets.py >/dev/null 2>&1; then
  ok "Store image sizes/metadata/trademark scan"
else
  bad "Store image sizes/metadata/trademark scan (run tool/check_store_assets.py)"
fi

echo
if [[ "$FAILED" == "0" ]]; then
  echo "VERIFY PASSED (local checks only; console submission remains manual)."
  exit 0
else
  echo "VERIFY FAILED — resolve the FAIL items above."
  exit 1
fi
