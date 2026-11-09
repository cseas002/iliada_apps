# Iliada Apps

The app catalog behind the **Iliada Store**.

Every app in Iliada is a self-contained, sandboxed `.app` bundle. This
repository says *which* apps exist and *how* each is built; the built bundles
are published as release files, and a signed `catalog.json` tells the Store
what is available.

```
recipes/<name>.toml    one file per app: where it comes from, what it needs
CATALOG.md             the catalog and archive formats
```

## How an app gets into the Store

1. A recipe is added here (see below).
2. The Iliada build server runs the Package Translator on it: the upstream
   package becomes `Name.app` (dependencies bundled, provenance recorded),
   which is packed into `Name.app.tar.zst`.
3. The archive is uploaded as a release of this repository, and its SHA-256
   goes into `catalog.json`, which is signed with the Iliada catalog key.
4. The Store downloads the catalog, checks its signature against the key
   built into Iliada, and installs an app by downloading its archive,
   checking the hash, and unpacking it into `/Applications`, exactly as if
   the user had dragged the `.app` there.

## Recipes

```toml
# recipes/firefox.toml
name = "Firefox"
summary = "Browse the web"
category = "Internet"              # Internet, Office, Graphics, Media, Utilities, Games, Development
source = { debian = "firefox-esr" }
exec = "firefox-esr"               # optional: which program to start
network = true                     # optional: the app needs the internet (shown in the Store)
full_closure = false               # optional: also bundle non-library dependencies
```

An app is only added to the catalog after it passes a launch test in the
Iliada test VM.

## Licences

The recipes and tooling here are MIT OR Apache-2.0. Each app keeps its own
licence; it is recorded in the app's bundle.
