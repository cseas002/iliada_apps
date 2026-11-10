#!/usr/bin/env bash
# Publish the apps listed in a signed catalog, then the catalog itself.
#
#   scripts/publish.sh <out-dir>
#
# <out-dir> is the catalog builder's --out: it holds catalog-2.json (every
# processor), catalog.json (x86-64 only, for Iliada 0.1), their .sig files,
# and dist/<tag>/<files>. Only apps that are in the catalogs (i.e. passed the
# launch test) are uploaded. Each app version is its own release
# (tag = <recipe>-<version>), holding one archive per processor; files a
# release already has are never replaced (the catalog signed their hashes).
# The catalogs live in the rolling "catalog" release.
set -euo pipefail
OUT="${1:?usage: publish.sh <out-dir>}"
REPO="${ILIADA_APPS_REPO:-cseas002/iliada_apps}"
[ -f "$OUT/catalog.json" ] || { echo "catalog.json missing in $OUT" >&2; exit 1; }
catalogs=()
for c in catalog.json catalog-2.json; do
  [ -f "$OUT/$c" ] || continue
  [ -f "$OUT/$c.sig" ] || { echo "$c.sig missing in $OUT" >&2; exit 1; }
  catalogs+=("$OUT/$c" "$OUT/$c.sig")
done

# Every file the catalogs point at (archives and icons): "<tag>/<file>".
files=$(cat "$OUT"/catalog*.json | grep -oE '"(url|icon)": *"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' |
  awk -F/ '{print $(NF-1) "/" $NF}' | sort -u)
tags=$(cut -d/ -f1 <<<"$files" | sort -u)

for tag in $tags; do
  if gh release view "$tag" -R "$REPO" >/dev/null 2>&1; then
    have=$(gh release view "$tag" -R "$REPO" --json assets -q '.assets[].name')
    new=()
    for f in $(grep "^$tag/" <<<"$files" | cut -d/ -f2-); do
      grep -qxF "$f" <<<"$have" || new+=("$OUT/dist/$tag/$f")
    done
    if [ ${#new[@]} -gt 0 ]; then
      echo "adding to $tag: ${new[*]##*/}"
      gh release upload "$tag" -R "$REPO" "${new[@]}"
    else
      echo "exists: $tag"
    fi
  else
    echo "publishing: $tag"
    gh release create "$tag" -R "$REPO" --title "$tag" --latest=false \
      --notes "Built by the Iliada catalog builder from its recipe." \
      $(grep "^$tag/" <<<"$files" | sed "s|^|$OUT/dist/|")
  fi
done

gh release view catalog -R "$REPO" >/dev/null 2>&1 ||
  gh release create catalog -R "$REPO" --title "Catalog" --latest=false \
    --notes "The signed Iliada app catalog (updated in place)."
gh release upload catalog -R "$REPO" --clobber "${catalogs[@]}"
echo "catalog published: https://github.com/$REPO/releases/download/catalog/"
