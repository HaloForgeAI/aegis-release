# Aegis Public Release

Public native installers and release assets for Aegis, the HaloForgeAI personal AI assistant hub.

This repository is the user-facing distribution layer. The private source repo builds native bundles; this public repo hosts the install scripts, checksums, and downloadable release assets.

## Pick An Install Mode

| Mode | Use when | What runs locally |
| --- | --- | --- |
| Full self-host | You want your own Aegis Server on this machine | `aegis-server`, `aegis` CLI, and Local Gateway |
| Worker-only | You already have an Aegis Server URL and owner token | `aegis` CLI and Local Gateway |
| Agent plugin | You mainly use Codex, Claude Code, or another MCP client | Agent plugin connects to an existing Aegis Server |

The recommended shape is native: Aegis Server owns planning, state, queueing, and audit; Local Gateway stays on your host so Aegis can use your files, terminal, browser, GUI, and local MCP servers with explicit tool-call evidence.

The default install is local-first. It uses SQLite and a local attachments directory, so you do not need PostgreSQL, Redis, S3, or any separate service to try Aegis on one machine.

## Before You Install

Required:

- macOS Apple Silicon, Linux x64, or Windows x64.
- Internet access to GitHub Releases.

Optional, depending on what you want Aegis to do:

- LLM provider credentials: `AEGIS_LLM_BASE_URL`, `AEGIS_LLM_MODEL`, `AEGIS_LLM_API_KEY`.
- Telegram bot token from BotFather: `AEGIS_TELEGRAM_BOT_TOKEN`.
- Agent plugins from [`HaloForgeAI/aegis-agent-plugins`](https://github.com/HaloForgeAI/aegis-agent-plugins).

Channels are not mandatory. You can start with the CLI, an agent plugin, or MCP access first, then add Telegram or other channels later.

## macOS / Linux Full Self-Host

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | bash
```

Pin a release:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | AEGIS_VERSION=v0.1.2 bash
```

Check the install:

```bash
~/.aegis/bin/aegis --root ~/.aegis/profiles/release status
~/.aegis/bin/aegis --root ~/.aegis/profiles/release onboarding doctor
~/.aegis/bin/aegis --root ~/.aegis/profiles/release worker tools --no-exec
```

## Windows Full Self-Host

```powershell
iwr https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.ps1 -OutFile install-aegis.ps1
powershell -ExecutionPolicy Bypass -File .\install-aegis.ps1
```

Pin a release:

```powershell
$env:AEGIS_VERSION = "v0.1.2"
powershell -ExecutionPolicy Bypass -File .\install-aegis.ps1
```

Check the install:

```powershell
& "$HOME\.aegis\bin\aegis.exe" --root "$HOME\.aegis\profiles\release" status
& "$HOME\.aegis\bin\aegis.exe" --root "$HOME\.aegis\profiles\release" onboarding doctor
& "$HOME\.aegis\bin\aegis.exe" --root "$HOME\.aegis\profiles\release" worker tools --no-exec
```

## Worker-Only: Connect This Machine

Use this when an Aegis Server is already running somewhere else.

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | \
  AEGIS_SERVER_URL="https://aegis.example.com" \
  AEGIS_ACCESS_TOKEN="paste-owner-token-here" \
  bash -s -- --worker-only
```

Windows:

```powershell
$env:AEGIS_SERVER_URL = "https://aegis.example.com"
$env:AEGIS_ACCESS_TOKEN = "paste-owner-token-here"
iwr https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.ps1 -OutFile install-aegis.ps1
powershell -ExecutionPolicy Bypass -File .\install-aegis.ps1 -WorkerOnly
```

After that, start the Local Gateway for the workspace you want Aegis to operate:

```bash
aegis --root ~/.aegis/profiles/release local-gateway --workspace-root ~/work --max-workers 2
```

## Configure Optional Channels

For a self-host install, edit `~/.aegis/profiles/release/.env` and restart native services.

```bash
cd ~/.aegis/profiles/release
$EDITOR .env
aegis --root ~/.aegis/profiles/release up
```

Common optional keys:

```dotenv
AEGIS_LLM_BASE_URL=https://api.openai.com/v1
AEGIS_LLM_MODEL=gpt-4.1
AEGIS_LLM_API_KEY=...

AEGIS_TELEGRAM_BOT_TOKEN=...
AEGIS_TELEGRAM_OWNER_ID=owner
AEGIS_TELEGRAM_MODE=polling
```

## Stop Or Remove

macOS / Linux:

```bash
~/.aegis/profiles/release/scripts/aegis-stop.sh
~/.aegis/profiles/release/scripts/aegis-stop.sh --purge
```

Windows:

```powershell
& "$HOME\.aegis\profiles\release\scripts\aegis-stop.ps1"
& "$HOME\.aegis\profiles\release\scripts\aegis-stop.ps1" -Purge
```

CLI lifecycle commands:

```bash
aegis --root ~/.aegis/profiles/release stop
aegis --root ~/.aegis/profiles/release down
aegis --root ~/.aegis/profiles/release down --purge
```

## Repository Roles

| Repository | Visibility | Owns |
| --- | --- | --- |
| `HaloForgeAI/Aegis` | Private | Runtime source, release workflow, internal docs, implementation decisions |
| `HaloForgeAI/aegis-release` | Public | Public installers, native release assets, checksums, install runbooks |
| `HaloForgeAI/aegis-site` | Public | Brand site, quickstart copy, SEO, Cloudflare Pages deployment |
| `HaloForgeAI/aegis-agent-plugins` | Public | Codex, Claude Code, and agent plugin distribution |

Do not hand-edit generated release assets here. Native bundles and `SHA256SUMS` should be produced by the private Aegis release workflow, then mirrored into GitHub Releases in this repository.

## Public Launch Check

Maintainers can check the public gates with:

```bash
scripts/check-public-release.sh v0.1.2
```

The check verifies native bundle downloads and checksums.

More detail lives in [docs/PUBLIC-RELEASE-RUNBOOK.md](docs/PUBLIC-RELEASE-RUNBOOK.md).
