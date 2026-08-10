#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
alr=$("$project_root/scripts/find-alr.sh")
documentation_output="$project_root/docs/api"
website_kit="$project_root/vendor/website-kit"
warning_baseline_file="$project_root/docs/gnatdoc-warning-baseline.txt"

if [ ! -f "$website_kit/scripts/render-gnatdoc-theme.mjs" ]; then
   printf '%s\n' \
     "website kit is unavailable; run: git submodule update --init" >&2
   exit 1
fi

if ! command -v gnatdoc >/dev/null 2>&1; then
   installed_gnatdoc=${ALIRE_INSTALL_PREFIX:-"$HOME/.alire"}/bin/gnatdoc
   if [ ! -x "$installed_gnatdoc" ]; then
      printf '%s\n' \
        "gnatdoc not found; install it with: $alr install gnatdoc_bin" >&2
      exit 1
   fi
   PATH=$(dirname "$installed_gnatdoc"):$PATH
   export PATH
fi

case "$documentation_output" in
   "$project_root"/docs/api) ;;
   *)
      printf '%s\n' \
        "refusing unsafe documentation output path: $documentation_output" >&2
      exit 1
      ;;
esac

cd "$project_root"
"$alr" build --stop-after=generation
rm -rf "$documentation_output"
node "$website_kit/scripts/render-gnatdoc-theme.mjs" \
  "$project_root/docs/gnatdoc-theme.json" \
  "$project_root/docs/gnatdoc/html"
gnatdoc_log=$(mktemp -t flyology-tui-gnatdoc.XXXXXX)
trap 'rm -f "$gnatdoc_log"' EXIT HUP INT TERM
if ! "$alr" exec -- gnatdoc \
  --backend=html \
  --generate=public \
  --warnings \
  --style=leading \
  -P flyology_tui.gpr \
  -O docs/api >"$gnatdoc_log" 2>&1
then
   cat "$gnatdoc_log" >&2
   exit 1
fi
cat "$gnatdoc_log"
warning_count=$(grep -c 'warning:' "$gnatdoc_log" || true)
warning_baseline=$(cat "$warning_baseline_file")
if [ "$warning_count" -gt "$warning_baseline" ]; then
   printf '%s\n' \
     "GNATdoc warning count increased: $warning_count > $warning_baseline" >&2
   exit 1
fi
printf '%s\n' \
  "GNATdoc warnings: $warning_count (must not exceed $warning_baseline)"
rm -f "$gnatdoc_log"
trap - EXIT HUP INT TERM

node "$project_root/scripts/normalize-gnatdoc-html.mjs" docs/api

mkdir -p docs/api/fonts
cp "$website_kit/assets/fonts/geologica-latin-variable.woff2" \
  docs/api/fonts/
cp website/assets/brand/flyology-mark-transparent.svg \
  docs/api/flyology-mark.svg
cp "$website_kit/assets/scripts/ada-highlight.js" docs/api/ada-highlight.js
node "$website_kit/scripts/build-api-search-index.mjs" docs/api
if grep -q 'FlyologyApiSearch = \[\];' docs/api/search-index.js; then
   node "$project_root/scripts/build-legacy-api-index.mjs" docs/api
fi

test -f docs/api/index.html
test -f docs/api/search-index.js
