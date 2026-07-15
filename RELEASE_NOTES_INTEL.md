# v0.11.1 Intel Mac / x86_64

Unofficial Intel Mac build of upstream Craft Agents **v0.11.1** for macOS x86_64.

Official upstream macOS releases currently provide Apple Silicon / arm64 artifacts only. This fork release provides Intel-compatible artifacts built from the v0.11.1 codebase plus fork-specific Intel build tooling.

## Assets

Upload these files from `~/.craft-agent/src/craft-agents-oss/apps/electron/release/` after a successful Intel build:

- `Craft-Agents-x64.dmg`
- `Craft-Agents-x64.dmg.blockmap`
- `Craft-Agents-x64.zip`
- `Craft-Agents-x64.zip.blockmap`
- `latest-mac.yml`

## Verification

Confirm architecture:

```bash
lipo -archs "$HOME/.craft-agent/src/craft-agents-oss/apps/electron/release/mac/Craft Agents.app/Contents/MacOS/Craft Agents"
# expected: x86_64
```

Confirm version:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$HOME/.craft-agent/src/craft-agents-oss/apps/electron/release/mac/Craft Agents.app/Contents/Info.plist"
# expected: 0.11.1
```

SHA256 checksums for the build produced on 2026-07-15:

```text
9fa9506f71d5a2b08314c1fa34c341fbfbe73095fc7a0c1ffee2e3f7e9d25a32  Craft-Agents-x64.dmg
9d620712f1af7572a42ccd88ffd1a18da943ad345f28c7a81f01c7bf9c47d09b  Craft-Agents-x64.zip
```

Regenerate checksums if you rebuild before publishing:

```bash
cd "$HOME/.craft-agent/src/craft-agents-oss/apps/electron/release"
shasum -a 256 Craft-Agents-x64.dmg Craft-Agents-x64.zip
```

## macOS first launch

This build is ad-hoc signed, not Apple-notarized. On first launch, right-click **Craft Agents.app** → **Open**, or clear quarantine:

```bash
xattr -c "/Applications/Craft Agents.app"
```
