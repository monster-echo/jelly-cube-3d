#!/usr/bin/env bash
# Build signed store artifacts. This script never uploads or publishes.
# Requires release.env and app-specific signing assets; fails closed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f release.env ]]; then
  # shellcheck disable=SC1091
  source release.env
else
  echo "Missing release.env. Copy release.env.example and fill in the non-secret values." >&2
  exit 2
fi

APP_NAME="${APP_NAME:-Jelly Cube 3D}"
BUNDLE_ID="${BUNDLE_ID:-tech.zhongbei.jellycube3d}"
APPLE_EXPORT_METHOD="${APPLE_EXPORT_METHOD:-app-store}"
RELEASE_NAME="${RELEASE_NAME:-$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)}"
RELEASE_NUMBER="${RELEASE_NUMBER:-$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f2)}"
OUT="$ROOT/build/release/${RELEASE_NAME}+${RELEASE_NUMBER}"
mkdir -p "$OUT"

common_dart_defines=(
  --dart-define=APP_ENV=production
  --dart-define=APP_NAME="$APP_NAME"
  --dart-define=BUNDLE_ID="$BUNDLE_ID"
  --dart-define=IAP_PRODUCT_ID="${IAP_PRODUCT_ID:-tech.zhongbei.jellycube3d.extra_types}"
)
version_args=(--build-name="$RELEASE_NAME" --build-number="$RELEASE_NUMBER")

usage() {
  cat <<USAGE
Usage: scripts/build-release.sh <android|ios|harmony|all>

Android requires android/key.properties and an app-specific upload keystore.
iOS requires a distribution certificate and provisioning profile in the keychain.
HarmonyOS requires a Flutter-OHOS SDK, DEVECO_SDK_HOME, and ohos/ signing config.
No command uploads or publishes anything.
USAGE
}

build_android() {
  echo "== Android release =="
  if [[ ! -f android/key.properties ]]; then
    echo "BLOCKED: android/key.properties is missing. Create an app-specific upload keystore first." >&2
    return 3
  fi
  flutter build appbundle --release \
    "${version_args[@]}" "${common_dart_defines[@]}" \
    --obfuscate --split-debug-info="$OUT/symbols/android"
  cp build/app/outputs/bundle/release/app-release.aab "$OUT/jelly-cube-3d.aab"
  (cd "$OUT" && shasum -a 256 jelly-cube-3d.aab > jelly-cube-3d.aab.sha256)
  echo "AAB: $OUT/jelly-cube-3d.aab"
}

build_ios() {
  echo "== iOS release =="
  if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
    echo "BLOCKED: no Apple Distribution identity found in the keychain." >&2
    return 4
  fi
  flutter build ipa --release \
    "${version_args[@]}" "${common_dart_defines[@]}" \
    --export-method="$APPLE_EXPORT_METHOD" \
    --obfuscate --split-debug-info="$OUT/symbols/ios"
  local ipa
  ipa="$(find build/ios/ipa -name '*.ipa' -maxdepth 1 2>/dev/null | head -1 || true)"
  if [[ -z "$ipa" ]]; then
    # Xcode 27.1 + openrsync fails IDEDistributionCreateIPAStep with
    # "--extended-attributes: unknown option". The distribution pipeline has
    # already re-signed the app at this point, so recover that signed payload
    # and zip a valid IPA ourselves.
    echo "Flutter export produced no IPA; recovering Xcode distribution pipeline…"
    local pipeline=""
    pipeline="$(ls -dt "${TMPDIR:-/tmp}"/XcodeDistPipeline.* 2>/dev/null | head -1 || true)"
    if [[ -n "$pipeline" && -d "$pipeline/Root/Payload/Runner.app" ]]; then
      local app="$pipeline/Root/Payload/Runner.app"
      local cs
      cs="$(codesign -dv --verbose=4 "$app" 2>&1 || true)"
      if grep -q 'Authority=Apple Distribution' <<<"$cs"; then
        if security cms -D -i "$app/embedded.mobileprovision" 2>/dev/null             | plutil -extract Entitlements.get-task-allow raw - 2>/dev/null             | grep -q '^false$'; then
          /usr/bin/ditto -c -k --sequesterRsrc --keepParent             "$pipeline/Root/Payload" "$OUT/jelly-cube-3d.ipa"
          ipa="$OUT/jelly-cube-3d.ipa"
          echo "Recovered distribution-signed IPA from $pipeline"
        else
          echo "BLOCKED: recovered app does not use an App Store profile." >&2
          return 5
        fi
      else
        echo "BLOCKED: recovered app is not Apple Distribution-signed." >&2
        return 5
      fi
    else
      echo "BLOCKED: Flutter did not produce an IPA and no distribution pipeline was found." >&2
      return 5
    fi
  fi
  if [[ "$ipa" != "$OUT/jelly-cube-3d.ipa" ]]; then
    cp "$ipa" "$OUT/jelly-cube-3d.ipa"
  fi
  (cd "$OUT" && shasum -a 256 jelly-cube-3d.ipa > jelly-cube-3d.ipa.sha256)
  echo "IPA: $OUT/jelly-cube-3d.ipa"
}

build_harmony() {
  echo "== HarmonyOS release =="
  if [[ ! -d ohos ]]; then
    echo "BLOCKED: ohos/ is missing. Run the Flutter-OHOS host integration first." >&2
    return 6
  fi
  local flutter_ohos="${FLUTTER_OHOS:-$HOME/flutter-ohos-3.41.9/bin/flutter}"
  local sdk="${HARMONY_DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
  if [[ ! -x "$flutter_ohos" ]]; then
    echo "BLOCKED: Flutter-OHOS not found at $flutter_ohos." >&2
    return 7
  fi
  if [[ ! -d "$sdk" ]]; then
    echo "BLOCKED: DEVECO_SDK_HOME not found at $sdk." >&2
    return 8
  fi
  # Fail if signing config is empty; an unsigned HAP cannot be submitted.
  if ! grep -q '"signingConfigs"[[:space:]]*:[[:space:]]*\[[^]]' ohos/build-profile.json5 2>/dev/null; then
    echo "BLOCKED: ohos/build-profile.json5 has no signingConfigs. Add the AppGallery signing profile." >&2
    return 9
  fi
  # hvigor rejects apostrophes and other characters in the project path. Stage
  # the source in a sanitized /tmp directory for local builds; CI already runs
  # from a clean checkout.
  local stage
  stage="$(mktemp -d "${TMPDIR:-/tmp}/jelly-ohos.XXXXXX")"
  trap 'rm -rf "$stage"' RETURN
  rsync -a \
    --exclude build \
    --exclude .dart_tool \
    --exclude node_modules \
    --exclude oh_modules \
    --exclude local.properties \
    --exclude '.hvigor' \
    --exclude 'oh-package-lock.json5' \
    "$ROOT/" "$stage/"
  (
    cd "$stage"
    DEVECO_SDK_HOME="$sdk" "$flutter_ohos" pub get >/dev/null
    DEVECO_SDK_HOME="$sdk" "$flutter_ohos" build hap --release \
      "${version_args[@]}" "${common_dart_defines[@]}" \
      --obfuscate --split-debug-info="$OUT/symbols/ohos"
    local hap
    hap="$(find build/ohos/hap -name '*.hap' -maxdepth 1 | head -1 || true)"
    if [[ -z "$hap" ]]; then
      echo "BLOCKED: Flutter-OHOS did not produce a HAP." >&2
      exit 10
    fi
    cp "$hap" "$OUT/jelly-cube-3d.hap"
    (cd "$OUT" && shasum -a 256 jelly-cube-3d.hap > jelly-cube-3d.hap.sha256)
    echo "HAP: $OUT/jelly-cube-3d.hap"
  )
}

case "${1:-}" in
  android) build_android ;;
  ios) build_ios ;;
  harmony) build_harmony ;;
  all)
    build_android
    build_ios
    build_harmony
    ;;
  *)
    usage
    exit 1
    ;;
esac

echo "Done. Nothing was uploaded or published."
