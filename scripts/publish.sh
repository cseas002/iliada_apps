#!/usr/bin/env bash
# Publish the apps listed in a signed catalog, then the catalog itself.
#
#   scripts/publish.sh <out-dir>
#
# <out-dir> is the catalog builder's --out: it holds catalog.json,
# catalog.json.sig and dist/<tag>/<files>. Only apps that are in catalog.json
# (i.e. passed the launch test) are uploaded. Each app version is its own
# release (tag = <recipe>-<version>); the catalog lives in the rolling
# "catalog" release.
set -euo pipefail
OUT="${1:?usage: publish.sh <out-dir>}"
REPO="${ILIADA_APPS_REPO:-cseas002/iliada_apps}"
[ -f "$OUT/catalog.json" ] && [ -f "$OUT/catalog.json.sig" ] || { echo "catalog.json(.sig) missing in $OUT" >&2; exit 1; }

tags=$(python3 -c 'import json,sys
for a in json.load(open(sys.argv[1]))["apps"]:
    print(a["archive"]["url"].split("/")[-2])' "$OUT/catalog.json" | sort -u)

for tag in $tags; do
  if gh release view "$tag" -R "$REPO" >/dev/null 2>&1; then
    echo "exists: $tag"
  else
    echo "publishing: $tag"
    gh release create "$tag" -R "$REPO" --title "$tag" --latest=false \
      --notes "Built by the Iliada catalog builder from its recipe." "$OUT/dist/$tag"/*
  fi
done

gh release view catalog -R "$REPO" >/dev/null 2>&1 ||
  gh release create catalog -R "$REPO" --title "Catalog" --latest=false \
    --notes "The signed Iliada app catalog (updated in place)."
gh release upload catalog -R "$REPO" --clobber "$OUT/catalog.json" "$OUT/catalog.json.sig"
echo "catalog published: https://github.com/$REPO/releases/download/catalog/catalog.json"
