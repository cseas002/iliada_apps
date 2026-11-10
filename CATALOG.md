# Catalog format

Two signed catalogs are published side by side in the `catalog` release:

| File | Format | Read by | Lists |
|---|---|---|---|
| `catalog-2.json` | 2 | Iliada 0.2 and later | every app, one archive per processor |
| `catalog.json` | 1 | Iliada 0.1 | x86-64 (Intel/AMD) apps only |

Each is signed by `<file>.sig` (Ed25519 over the exact bytes of the file,
base64). The public key is built into Iliada. The Store is configured with
the `catalog.json` URL and prefers `catalog-2.json` next to it when it
exists. `catalog.json` keeps exactly the shape Iliada 0.1 parses: 0.1 refuses
fields it does not know, so new fields only ever go into `catalog-2.json`.

## catalog-2.json

```json
{
  "format": 2,
  "generated": 1794240000,
  "apps": [
    {
      "id": "org.debian.firefox-esr",
      "name": "Firefox",
      "summary": "Browse the web",
      "category": "Internet",
      "version": "140.4.0esr-1~deb13u1",
      "network": true,
      "archives": {
        "x86_64": {
          "url": "https://github.com/cseas002/iliada_apps/releases/download/firefox-140.4.0esr-1_deb13u1/firefox.app.tar.zst",
          "sha256": "…",
          "size": 98765432
        },
        "aarch64": {
          "url": "https://github.com/cseas002/iliada_apps/releases/download/firefox-140.4.0esr-1_deb13u1/firefox-arm64.app.tar.zst",
          "sha256": "…",
          "size": 91234567
        }
      },
      "icon": "https://github.com/cseas002/iliada_apps/releases/download/…/firefox.png"
    }
  ]
}
```

* `archives` is keyed by processor as Rust names it (`std::env::consts::ARCH`):
  `x86_64` or `aarch64`. The Store shows only apps with an archive for the
  computer it runs on.
* An archive may carry its own `"version"` when Debian's build for that
  processor differs from the entry's (`1:48.1-2+b2` on one, `+b1` on the
  other); the Store then compares installed apps against that version.
* Readers ignore entry fields they do not know.

## catalog.json (format 1)

The same entries for x86-64 only, with one `"archive"` object (`url`,
`sha256`, `size`) in place of `archives`.

## Archives

* Only the catalogs are signed; every archive is authenticated through its
  `sha256` in the signed catalog.
* An archive is a tar of exactly one top-level directory, `Name.app/`,
  compressed with zstd. The Store unpacks it with Iliada's path-checked
  extractor (no absolute paths, no `..`, no links out of the bundle).
* Each app version is one release (`<recipe>-<version>`), holding
  `<recipe>.app.tar.zst` (x86-64), `<recipe>-arm64.app.tar.zst` (ARM) and the
  icon. Files already published are never replaced.

## Building

```sh
iliada-catalog build --recipes recipes --out dist              # x86-64
iliada-catalog build --recipes recipes --out dist --arch arm64 # ARM
# launch-test dist/bundles and dist/bundles-arm64 (scripts/launch-test.sh)
iliada-catalog assemble --out dist --include firefox,gimp.amd64
iliada-catalog sign --key ~/.config/iliada/catalog.key dist/catalog.json dist/catalog-2.json
scripts/publish.sh dist
```

`--include` names recipes (every processor that was built) or
`recipe.amd64` / `recipe.arm64` (one processor), so an app that passes the
launch test on one processor only is published for that one.
