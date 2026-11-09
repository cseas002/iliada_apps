# Catalog format (version 1)

`catalog.json`, signed by `catalog.json.sig` (Ed25519 over the exact bytes of
`catalog.json`, base64). The public key is built into Iliada.

```json
{
  "format": 1,
  "generated": 1794240000,
  "apps": [
    {
      "id": "org.debian.firefox-esr",
      "name": "Firefox",
      "summary": "Browse the web",
      "category": "Internet",
      "version": "140.4.0esr-1~deb13u1",
      "network": true,
      "archive": {
        "url": "https://github.com/cseas002/iliada_apps/releases/download/firefox-140.4.0esr-1~deb13u1/Firefox.app.tar.zst",
        "sha256": "…",
        "size": 98765432
      },
      "icon": "https://github.com/cseas002/iliada_apps/releases/download/…/Firefox.png"
    }
  ]
}
```

* Only `catalog.json` is signed; every archive is authenticated through its
  `sha256` in the signed catalog.
* An archive is a tar of exactly one top-level directory, `Name.app/`,
  compressed with zstd. The Store unpacks it with Iliada's path-checked
  extractor (no absolute paths, no `..`, no links out of the bundle).
