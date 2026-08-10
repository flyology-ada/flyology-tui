#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SITE="$ROOT/build/site"
KIT="$ROOT/vendor/website-kit"

test -f "$KIT/scripts/install-assets.mjs" || {
  echo "website-kit submodule is missing; run git submodule update --init" >&2
  exit 1
}

case "$SITE" in
  "$ROOT"/build/site) ;;
  *) echo "refusing unexpected site path: $SITE" >&2; exit 1 ;;
esac

"$ROOT/scripts/docs.sh"
ALR_BIN=$("$ROOT/scripts/find-alr.sh")
(cd "$ROOT/examples" && "$ALR_BIN" build)
rm -rf "$SITE"
mkdir -p "$ROOT/build"
cp -R "$ROOT/website" "$SITE"
node "$KIT/scripts/install-assets.mjs" "$SITE"
mkdir -p "$SITE/api"
cp -R "$ROOT/docs/api/." "$SITE/api/"
node "$ROOT/scripts/generate-components-site.mjs" "$SITE"
node "$ROOT/scripts/resolve-api-links.mjs" "$SITE"
node "$ROOT/scripts/version-site-assets.mjs" "$SITE"
touch "$SITE/.nojekyll"
node "$KIT/scripts/check-site.mjs" "$SITE"

test -f "$SITE/index.html"
test "$(cat "$SITE/CNAME")" = "tui.flyology.org"
test -f "$SITE/llms.txt"
test -f "$SITE/guide/index.html"
test -f "$SITE/architecture/index.html"
test -f "$SITE/components/index.html"
test -f "$SITE/api/index.html"

COMPONENT_PAGES=$(find "$SITE/components" -mindepth 2 -maxdepth 2 -name index.html | wc -l | tr -d ' ')
PREVIEWS=$(find "$SITE/assets/captures" -name '*.svg' | wc -l | tr -d ' ')
test "$COMPONENT_PAGES" = 34
test "$PREVIEWS" = 48

echo "site built at $SITE ($COMPONENT_PAGES component pages, $PREVIEWS Ada captures)"
