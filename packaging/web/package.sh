#!/usr/bin/env bash
# Build the browser version and zip it:  $DIST/wordcraft-web-<version>.zip
#
# Usage: packaging/web/package.sh [--skip-build]
#
# Needs: trunk (brew install trunk / cargo install trunk --locked) and the wasm32-unknown-unknown
# target. The zip holds a self-contained static site in wordcraft-web-<version>/ that works
# from any URL path and inside an <iframe>. Hosting notes: packaging/web/README.md.
set -euo pipefail
# shellcheck source=../env.sh
. "$(dirname "${BASH_SOURCE[0]}")/../env.sh"
HERE="$ROOT/packaging/web"

if [[ "${1:-}" != "--skip-build" ]]; then
  command -v trunk >/dev/null || { echo "error: trunk not found (cargo install trunk --locked)" >&2; exit 1; }
  (cd "$ROOT/apps/wordcraft-web" && trunk build --release)
fi

SITE="$ROOT/dist/web"
[[ -f "$SITE/index.html" ]] || { echo "error: $SITE/index.html missing; run without --skip-build" >&2; exit 1; }
# Paths must be relative so the site works under any prefix (public_url = "./" in Trunk.toml).
if grep -Eq '(src|href)="/[^/]' "$SITE/index.html"; then
  echo "error: $SITE/index.html has root-absolute URLs; it would break when served from a sub-path" >&2
  exit 1
fi

NAME="wordcraft-web-$VERSION"
WORK="$CARGO_TARGET_DIR/web-package"
rm -rf "$WORK"
mkdir -p "$WORK/$NAME"
cp -R "$SITE/." "$WORK/$NAME/"
# Sample server configs (MIME type, caching, compression); harmless where unused.
cp "$HERE/_headers" "$HERE/.htaccess" "$WORK/$NAME/"
cp "$HERE/README.md" "$WORK/$NAME/HOSTING.md"
copy_docs "$WORK/$NAME"
# Script faces the app fetches at start (packaging/web/fonts.txt), each with its OFL licence.
if [[ -n "${CRAFT_FONTS_DIR:-}" ]]; then
  FONTS="$WORK/$NAME/fonts"
  mkdir -p "$FONTS"
  grep -v '^#' "$HERE/fonts.txt" | grep -v '^[[:space:]]*$' > "$FONTS/list.txt"
  while IFS='|' read -r _ file; do
    file="$(echo "$file" | xargs)"
    mkdir -p "$FONTS/$(dirname "$file")"
    cp "$CRAFT_FONTS_DIR/fonts/$file" "$FONTS/$file"
    cp "$CRAFT_FONTS_DIR/fonts/$(dirname "$file")/OFL.txt" "$FONTS/$(dirname "$file")/"
  done < "$FONTS/list.txt"
elif [[ -n "${CRAFT_FONTS_REQUIRED:-}" ]]; then
  echo "error: CRAFT_FONTS_DIR unset; the web build would draw Thai, Indic and CJK as boxes" >&2
  exit 1
fi
rm -f "$DIST/$NAME.zip"
(cd "$WORK" && zip -qr9 "$DIST/$NAME.zip" "$NAME")
echo "wrote $DIST/$NAME.zip"
ls -lh "$DIST/$NAME.zip"
