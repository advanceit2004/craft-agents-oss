# Building Craft Agents for Intel (x86_64) Macs

From **v0.10.4 onward, Craft Agents ships macOS as Apple Silicon (arm64) only** — both the
official GitHub releases and the hosted update channel (`agents.craft.do/electron`). The last
hosted Intel build is frozen at `0.10.1`. **Intel Mac users must therefore build from source.**

This repo includes a script that automates the entire build + install:
[`scripts/build-intel-mac.sh`](../scripts/build-intel-mac.sh).

## Quick start

```bash
bash scripts/build-intel-mac.sh v0.10.4
```

That clones the tag, installs dependencies, stages all build artifacts, packages an Intel
`.dmg`/`.zip`, ad-hoc signs it, backs up your current `/Applications/Craft Agents.app`, and
installs the new one. Then **quit Craft Agents (Cmd+Q) and reopen** to switch versions.

Build without installing:

```bash
bash scripts/build-intel-mac.sh v0.10.4 --no-install
# artifacts land in apps/electron/release/
```

## Requirements

- `bun`, `node`, `git`, `curl`, `unzip` (standard on a dev Mac)
- ~3 GB free disk, a working internet connection
- macOS on Intel (x86_64)

## What the script does (and why it's non-trivial)

The OSS repo **gitignores** several build artifacts that are normally staged by private CI, so a
clean build must produce and place them manually:

| Artifact | Staged to | Built by |
|---|---|---|
| session-mcp-server | `apps/electron/resources/session-mcp-server/index.js` | `bun run server:build:subprocess` |
| pi-agent-server | `apps/electron/resources/pi-agent-server/index.js` | `bun run server:build:subprocess` |
| WhatsApp worker | `packages/messaging-whatsapp-worker/dist/worker.cjs` | `bun run build:wa-worker` (**mandatory** — electron-builder errors without it) |
| uv (Python runtime) | `apps/electron/resources/bin/darwin-x64/uv` | downloaded (version pinned in `scripts/build/common.ts`) |
| Bun vendor runtime | `apps/electron/vendor/bun/bun` | downloaded (`bun-v1.3.9`) |
| Claude Agent SDK native binary | `apps/electron/node_modules/@anthropic-ai/claude-agent-sdk-binary/claude` | copied from `claude-agent-sdk-darwin-x64` |

It then runs `bun run electron:build` and packages with
`CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac --x64`, followed by an ad-hoc
`codesign`.

## Gotchas

- **Ad-hoc signed, not Apple-notarized.** First launch: right-click the app → **Open** once,
  or run `xattr -c "/Applications/Craft Agents.app"`.
- **Auto-update won't bump Intel** from the official channel (arm64-only manifest). To get
  Intel auto-updates, host your own release with a `latest-mac.yml` that includes the x64 entry
  (electron-builder generates one in `apps/electron/release/`) and point
  `apps/electron/electron-builder.yml`'s `publish.url` at your fork's releases.
- **Keep the Mac awake** during the build: prefix with `caffeinate -dimsu`.
- Electron runtime is cached after the first build, so later versions skip the ~112 MB download.

## Prebuilt Intel releases

Intel `.dmg`/`.zip` artifacts are published on this fork's
[Releases page](https://github.com/advanceit2004/craft-agents-oss/releases) when available, so you
can skip building entirely.
