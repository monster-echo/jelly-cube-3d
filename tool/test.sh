#!/usr/bin/env bash
# Flutter's test listener currently mishandles an apostrophe in the checkout
# path. Stage the project in a clean temporary directory before running tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
TMP="$TMP_ROOT/jelly_cube_3d"
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP"
rsync -a \
  --exclude build \
  --exclude .dart_tool \
  --exclude '*.iml' \
  "$ROOT/" "$TMP/"
cd "$TMP"
flutter pub get >/dev/null
exec flutter test "$@"
