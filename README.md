Desktop cat for macOS. See plan.md for scope/architecture.

## Install

1. Download `Ramona-<version>.dmg` from Releases, open it, drag Ramona into Applications.
2. First launch: right-click (or Control-click) Ramona in Applications and choose **Open** — the dmg is unsigned, so a plain double-click gets refused by Gatekeeper. This is only needed once.
3. Ramona lives in the menu bar (cat icon). Grant Accessibility access when prompted so she can sit on your windows.

## Build from source

```
swift build
```

`Scripts/build-dev-app.sh` builds and signs a local dev copy with a persistent certificate (see script comments for why). `Scripts/build-release-dmg.sh <version>` builds an unsigned release `.dmg` for distribution.
