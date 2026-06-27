#!/bin/bash
#
# build-craft-intel.sh — Build & install Craft Agents for Intel (x86_64) Macs from source.
#
# WHY THIS EXISTS:
#   The official Craft Agents releases (craft-ai-agents/craft-agents-oss) and the
#   hosted channel (agents.craft.do/electron) ship macOS as ARM64-ONLY from v0.10.4
#   onward. The hosted x64 zip is frozen at 0.10.1. So Intel Macs must build from source.
#
# USAGE:
#   bash build-craft-intel.sh <tag>        e.g. bash build-craft-intel.sh v0.10.4
#   bash build-craft-intel.sh v0.10.4 --no-install   # build only, don't touch /Applications
#
# REQUIREMENTS: bun, node, git, curl, unzip (all standard on a dev Mac).
# RESULT: /Applications/Craft Agents.app at the requested version (x86_64), old one backed up.
#
set -euo pipefail

TAG="${1:?Usage: build-craft-intel.sh <tag> [--no-install]}"
DO_INSTALL=true
[ "${2:-}" = "--no-install" ] && DO_INSTALL=false

REPO="https://github.com/craft-ai-agents/craft-agents-oss.git"
SRC="$HOME/.craft-agent/src/craft-agents-oss"
ARCH="x64"            # Intel
BUN_VERSION="bun-v1.3.9"   # keep in sync with apps/electron/scripts/build-dmg.sh

say() { printf "\n\033[1;34m=== %s ===\033[0m\n" "$1"; }

# 1. Clone (or refresh) the requested tag --------------------------------------
say "Clone $TAG"
rm -rf "$SRC"
git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
cd "$SRC"
ROOT="$PWD"; EL="$ROOT/apps/electron"

# 2. Install deps --------------------------------------------------------------
say "bun install"
bun install

# 3. Build + stage subprocess servers (gitignored build artifacts) -------------
say "Build & stage subprocess servers"
bun run server:build:subprocess
mkdir -p "$EL/resources/session-mcp-server" "$EL/resources/pi-agent-server"
cp packages/session-mcp-server/dist/index.js "$EL/resources/session-mcp-server/index.js"
cp packages/pi-agent-server/dist/index.js     "$EL/resources/pi-agent-server/index.js"

# 4. WhatsApp worker (mandatory electron-builder extraResource) ----------------
say "Build WhatsApp worker"
bun run build:wa-worker

# 5. uv binary (pinned in scripts/build/common.ts -> UV_VERSION) ---------------
say "Stage uv (Python runtime) for darwin-x64"
UV_VERSION="$(grep -E "export const UV_VERSION" scripts/build/common.ts | sed -E "s/.*'([0-9.]+)'.*/\1/")"
T="$(mktemp -d)"
curl -fSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-apple-darwin.tar.gz" -o "$T/uv.tgz"
tar -xzf "$T/uv.tgz" -C "$T"
mkdir -p "$EL/resources/bin/darwin-x64"
cp "$T/uv-x86_64-apple-darwin/uv" "$EL/resources/bin/darwin-x64/uv"
chmod +x "$EL/resources/bin/darwin-x64/uv"
rm -rf "$T"

# 6. Stage Bun vendor runtime --------------------------------------------------
say "Stage Bun vendor ($BUN_VERSION, darwin-x64)"
mkdir -p "$EL/vendor/bun"
T="$(mktemp -d)"
curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/bun-darwin-x64.zip" -o "$T/bun.zip"
unzip -oq "$T/bun.zip" -d "$T"
cp "$T/bun-darwin-x64/bun" "$EL/vendor/bun/bun"
chmod +x "$EL/vendor/bun/bun"
rm -rf "$T"

# 7. Stage SDK (host is x64, so the binary pkg is already in node_modules) ------
say "Stage Claude Agent SDK (core + x64 native binary)"
mkdir -p "$EL/node_modules/@anthropic-ai" "$EL/node_modules/@vscode"
rm -rf "$EL/node_modules/@anthropic-ai/claude-agent-sdk"
cp -r "$ROOT/node_modules/@anthropic-ai/claude-agent-sdk" "$EL/node_modules/@anthropic-ai/"
ALIAS="$EL/node_modules/@anthropic-ai/claude-agent-sdk-binary"
rm -rf "$ALIAS"; mkdir -p "$ALIAS"
cp -r "$ROOT/node_modules/@anthropic-ai/claude-agent-sdk-darwin-x64/." "$ALIAS/"
chmod +x "$ALIAS/claude"
# ripgrep + interceptor sources
rm -rf "$EL/node_modules/@vscode/ripgrep"
cp -r "$ROOT/node_modules/@vscode/ripgrep" "$EL/node_modules/@vscode/"
mkdir -p "$EL/packages/shared/src"
for f in unified-network-interceptor.ts interceptor-common.ts feature-flags.ts interceptor-request-utils.ts; do
  [ -f "$ROOT/packages/shared/src/$f" ] && cp "$ROOT/packages/shared/src/$f" "$EL/packages/shared/src/"
done

# 8. Build the Electron app ----------------------------------------------------
say "electron:build (main/preload/renderer/resources)"
bun run electron:build

# 9. Package x64 only (skip signing; ad-hoc later) -----------------------------
say "electron-builder --mac --x64"
cd "$EL"
CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac --x64 --config electron-builder.yml
APP="$EL/release/mac/Craft Agents.app"
codesign --force --deep --sign - "$APP"
echo "Built: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist") / $(lipo -archs "$APP/Contents/MacOS/Craft Agents")"

# 10. Install ------------------------------------------------------------------
if [ "$DO_INSTALL" = true ]; then
  say "Install to /Applications (old version backed up)"
  DEST="/Applications/Craft Agents.app"
  if [ -d "$DEST" ]; then
    OLDV="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
    BK="$HOME/.craft-agent/app-backup/Craft Agents ${OLDV}.app"
    mkdir -p "$HOME/.craft-agent/app-backup"; rm -rf "$BK"; ditto "$DEST" "$BK"
    echo "Backed up old ($OLDV) -> $BK"
  fi
  rm -rf "$DEST"; ditto "$APP" "$DEST"
  xattr -c "$DEST" 2>/dev/null || true
  echo "Installed: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist") / $(lipo -archs "$DEST/Contents/MacOS/Craft Agents")"
  echo ">>> QUIT Craft Agents (Cmd+Q) and reopen to switch to the new version. <<<"
else
  echo "Build only. Artifacts in: $EL/release/"
fi
