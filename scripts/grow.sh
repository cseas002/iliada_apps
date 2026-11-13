#!/usr/bin/env bash
# Grow the catalog by itself: add the most used Debian desktop apps that
# aren't in it yet. Run on the build server.
#
#   scripts/grow.sh [count]          (default 5; DRY_RUN=1: build and test, publish nothing)
#
# 1. Debian's app list (AppStream) and popularity contest are downloaded.
# 2. `iliada-catalog suggest` writes recipes for the <count> most used apps
#    that have no recipe and were not rejected before.
# 3. They are built for Intel/AMD and launch-tested in the dev VM
#    (scripts/launch-test.sh: it must start and keep running).
# 4. Apps that start are kept; the others lose their recipe and are listed
#    in rejected.txt with the reason, so they aren't tried again.
# 5. The catalog is assembled, signed and published (scripts/publish.sh), and
#    the new recipes and rejected.txt are committed and pushed.
set -euo pipefail
COUNT="${1:-5}"
APPS="$(cd "$(dirname "$0")/.." && pwd)"
OS="${ILIADA_OS:-$HOME/iliada_os}"
OUT="${ILIADA_DIST:-$HOME/iliada-dist}"
KEY="${ILIADA_CATALOG_KEY:-$HOME/.config/iliada/catalog.key}"
TARGET="${CARGO_TARGET_DIR:-$HOME/iliada-build/target}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export NIX_CONFIG="experimental-features = nix-command flakes"

echo "== building the catalog tool"
(cd "$OS" && nix develop -c bash -c "CARGO_TARGET_DIR='$TARGET' cargo build -q --release -p iliada-catalog --features builder")
CAT="$TARGET/release/iliada-catalog"

echo "== Debian's app list and popularity"
curl -sSf https://deb.debian.org/debian/dists/trixie/main/dep11/Components-amd64.yml.xz | xz -d > "$WORK/apps.yml"
curl -sSf https://popcon.debian.org/by_inst.gz | gzip -d > "$WORK/popcon.txt"
touch "$APPS/rejected.txt"
mapfile -t new < <("$CAT" suggest --recipes "$APPS/recipes" --apps "$WORK/apps.yml" --popcon "$WORK/popcon.txt" \
  --rejected "$APPS/rejected.txt" --count "$COUNT")
if [ ${#new[@]} -eq 0 ]; then echo "nothing new to add"; exit 0; fi
echo "trying: ${new[*]}"

reject() { # <stem> <reason>
  local pkg; pkg=$(sed -n 's/^source = { debian = "\(.*\)" }/\1/p' "$APPS/recipes/$1.toml")
  echo "$pkg  # $(date +%F) $2" >> "$APPS/rejected.txt"
  rm -f "$APPS/recipes/$1.toml" "$OUT/entries/$1.json"
  echo "   rejected $1 ($pkg): $2"
}

echo "== building"
(cd "$OS" && nix develop -c "$CAT" build --recipes "$APPS/recipes" --out "$OUT" \
  --cache "$HOME/.cache/iliada-ingest" --only "$(IFS=,; echo "${new[*]}")") > "$WORK/build.log" 2>&1 || true
kept=()
bundles=()
for stem in "${new[@]}"; do
  name=$(sed -n 's/^name = "\(.*\)"/\1/p' "$APPS/recipes/$stem.toml")
  if [ ! -f "$OUT/entries/$stem.json" ] || [ ! -d "$OUT/bundles/$name.app" ]; then
    reject "$stem" "could not be built: $(grep -A1 "$stem" "$WORK/build.log" | grep -m1 FAILED | sed 's/.*FAILED: //' | cut -c1-120)"
    continue
  fi
  kept+=("$stem"); bundles+=("$name.app")
done

if [ ${#bundles[@]} -gt 0 ]; then
  echo "== launch test (dev VM)"
  "$APPS/scripts/launch-test.sh" "$OUT/bundles" "$WORK/results" "${bundles[@]}" > "$WORK/launch.log" 2>&1 || true
  passed=()
  for stem in "${kept[@]}"; do
    name=$(sed -n 's/^name = "\(.*\)"/\1/p' "$APPS/recipes/$stem.toml")
    line=$(grep -F "${name// /_}" "$WORK/results/summary.txt" | head -1 || true)
    [ -n "$line" ] || line=$(grep -F "$name" "$WORK/results/summary.txt" | head -1 || true)
    if grep -q " running " <<<"$line"; then
      passed+=("$stem")
    else
      reject "$stem" "did not start: $(cut -c34- <<<"$line" | cut -c1-100)"
    fi
  done
  kept=("${passed[@]}")
fi
echo "== kept: ${kept[*]:-none}"
cat "$WORK/results/summary.txt" 2>/dev/null || true
if [ ${#kept[@]} -eq 0 ]; then
  [ -n "${DRY_RUN:-}" ] || { git -C "$APPS" add rejected.txt; git -C "$APPS" commit -qm "Catalog builder: none of ${new[*]} worked" && git -C "$APPS" push -q; }
  exit 0
fi
if [ -n "${DRY_RUN:-}" ]; then echo "DRY_RUN: not publishing"; exit 0; fi

echo "== catalog"
"$CAT" assemble --out "$OUT"
"$CAT" sign --key "$KEY" "$OUT/catalog.json" "$OUT/catalog-2.json"
"$APPS/scripts/publish.sh" "$OUT"
git -C "$APPS" add recipes rejected.txt
git -C "$APPS" commit -qm "Catalog builder: add ${kept[*]}

Tried the most used Debian desktop apps without a recipe; these built and
started in the launch test. The others are in rejected.txt."
git -C "$APPS" push -q
echo "== published: ${kept[*]}"
