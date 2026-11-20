# Iliada Apps

The app catalog behind the **Iliada Store**.

Every app in Iliada is a self-contained, sandboxed `.app` bundle. This
repository says *which* apps exist and *how* each is built; the built bundles
are published as release files, and a signed catalog (`catalog-2.json`; and
`catalog.json` for Iliada 0.1) tells the Store what is available. Every app
is built for Intel/AMD (x86-64) and ARM (aarch64) computers.

```
recipes/<name>.toml    one file per app: where it comes from, what it needs
CATALOG.md             the catalog and archive formats
```

## How an app gets into the Store

1. A recipe is added here (see below).
2. The Iliada build server runs the Package Translator on it: the upstream
   package becomes `Name.app` (dependencies bundled, provenance recorded),
   which is packed into `Name.app.tar.zst`, once per processor.
3. The archive is uploaded as a release of this repository, and its SHA-256
   goes into the catalog, which is signed with the Iliada catalog key.
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
folders = ["downloads"]            # optional: user folders it works with (asked on first launch)
permissions = [{ capability = "sound", purpose = "To play sound." }]
```

Other optional fields: `include = ["pkg", …]` (extra packages unpacked into
the app itself: plugins, programs outside the library path) and
`args = ["--flag"]` (always passed to the program) and
`env = { NAME = "value" }` (always set for the app) and
`copy = { "dest" = "source" }` (files put in place inside the app, both
paths relative to it: what a Debian install script would have done; Iliada
never runs those). `[write]` adds files with the given contents
(`"usr/lib/firefox-esr/distribution/policies.json" = '''…'''`): settings a
distribution would ship, such as the browsers' Bitwarden policy.

Apps Debian doesn't carry come from the maker's own `.deb`, pinned by its
SHA-256: `source = { url = "https://…/app_1.0_amd64.deb", sha256 = "…",
vendor = "com.example" }` (`vendor` is the app id's prefix; `arch`, default
`amd64`, says which processor the .deb is for, and other processors skip the
recipe). Its dependencies still come from Debian. See `recipes/bitwarden.toml`.

Permissions: every app runs in its own sandbox and sees only its own data.
`folders` (documents, downloads, music, pictures, videos) are asked for the
first time the app runs, in a window Iliada draws; the answer can be changed
in Settings → Privacy. `permissions` takes any capability from
`Permissions.toml` (`sound` is granted without asking; `camera` and
`microphone` are asked). Apps that link audio libraries get `sound` (and may
ask for the microphone) without declaring it. Declare only what the app
obviously needs.
`not_needed = ["microphone"]` drops a guessed permission the app never uses
(Okular, GIMP, Thunderbird and VLC link audio libraries but never record).

Rebuilding an app whose Debian version has not changed (a recipe change):
raise `build` (`build = 1` publishes 48.1-3 as 48.1-3+iliada1). A published
version is never replaced; systems update to the new one.

An app is only added to the catalog after it passes a launch test in the
Iliada test VM, for each processor (the ARM build in an emulated ARM VM).

## Google Chrome

Google's licence does not allow redistributing Chrome, so it cannot be in this
catalog. **Chromium** (the open-source browser Chrome is built from) is. Chrome
itself will be offered as an *on-device* recipe: the Store points at Google's
official download and the user's own machine translates it into a `.app`.

## Sources and licences

Every app here is built, unmodified, from Debian stable packages, except
Bitwarden, which is Bitwarden's own GPL-3.0 `.deb` from its GitHub releases
(source: github.com/bitwarden/clients at the same tag), with Debian packages
for its dependencies. Each bundle's
`Contents/Provenance.toml` lists every package it contains, with exact
versions, download URLs and SHA-256 hashes. The corresponding source code for
each of those versions is published by Debian (`deb.debian.org`, and
permanently at `snapshot.debian.org`). Each app keeps its own licence (see
`/usr/share/doc/<package>/copyright` inside the bundle), and names and logos
belong to their owners (e.g. Firefox and Thunderbird are Mozilla trademarks).

## Licences

The recipes and tooling here are MIT OR Apache-2.0. Each app keeps its own
licence; it is recorded in the app's bundle.
