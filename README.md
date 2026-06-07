# Aegis Public Release

Public installers and release assets for Aegis, the HaloForgeAI AI chief-of-staff.

This repository is the user-facing distribution layer. The private source repo
builds the server image and CLI binaries; this public repo hosts the install
scripts, compose template, checksums, and downloadable release assets.

## Pick An Install Mode

| Mode | Use when | What runs locally |
| --- | --- | --- |
| Full self-host | You want your own Aegis Server on this machine | Docker control plane plus the `aegis` CLI |
| Worker-only | You already have an Aegis Server URL and owner token | `aegis` CLI and Local Gateway worker |
| Agent plugin | You mainly use Codex, Claude Code, or another MCP client | Agent plugin connects to an existing Aegis Server |

The recommended shape is hybrid: Docker runs the durable control plane, while
the Local Gateway stays on your host so Aegis can use your files, terminal,
browser, GUI, and local MCP servers with explicit tool-call evidence.

There is no public standalone non-Docker Aegis Server installer. If you need a
server, use the full Docker self-host path. Worker-only installs connect this
machine to a server that already exists.

## Before You Install

Required for full self-host:

- macOS Apple Silicon or Windows x64.
- Docker Desktop or Docker Engine with Compose v2.
- Internet access to GitHub Releases and public GHCR.

Required for worker-only:

- macOS Apple Silicon or Windows x64.
- An existing Aegis Server URL.
- An owner access token for that server.

Optional, depending on what you want Aegis to do:

- LLM provider credentials: `AEGIS_LLM_BASE_URL`, `AEGIS_LLM_MODEL`,
  `AEGIS_LLM_API_KEY`.
- Telegram bot token from BotFather: `AEGIS_TELEGRAM_BOT_TOKEN`.
- Other channel secrets as they become available.
- Agent plugins from
  [`HaloForgeAI/aegis-agent-plugins`](https://github.com/HaloForgeAI/aegis-agent-plugins).

Channels are not mandatory. You can start with the CLI, an agent plugin, or MCP
access first, then add Telegram or other channels later.

## macOS Full Self-Host

This installs the macOS arm64 CLI, creates `~/.aegis/self-host`, writes a local
`.env`, starts Docker Compose, and stores a bootstrap owner token under
`~/.aegis/self-host/.aegis/access-token.txt`.

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | bash
```

Pin a release:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | AEGIS_VERSION=v0.1.2 bash
```

Check the install:

```bash
~/.local/bin/aegis --root ~/.aegis/self-host status
~/.local/bin/aegis --root ~/.aegis/self-host onboarding doctor
~/.local/bin/aegis --root ~/.aegis/self-host worker tools --no-exec
```

## Windows Full Self-Host

Run PowerShell as the user who will own the install:

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
~\.aegis\bin\aegis.exe --root "$HOME\.aegis\self-host" status
~\.aegis\bin\aegis.exe --root "$HOME\.aegis\self-host" onboarding doctor
~\.aegis\bin\aegis.exe --root "$HOME\.aegis\self-host" worker tools --no-exec
```

## Worker-Only: Connect This Machine

Use this when an Aegis Server is already running somewhere else. This is not a
non-Docker Aegis Server install. The installer downloads the CLI, writes the
server URL into the local `.env`, stores the owner token, and prepares this
machine to run Local Gateway worker slots.

macOS:

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
aegis --root ~/.aegis/self-host local-gateway --workspace-root ~/work --max-workers 2
```

## Configure Optional Channels

For a self-host install, edit `~/.aegis/self-host/.env` and restart the stack.

```bash
cd ~/.aegis/self-host
$EDITOR .env
docker compose -p aegis --env-file .env -f docker/docker-compose.yml up -d
```

Common optional keys:

```dotenv
AEGIS_LLM_BASE_URL=https://api.openai.com/v1
AEGIS_LLM_MODEL=gpt-4.1
AEGIS_LLM_API_KEY=...

AEGIS_TELEGRAM_BOT_TOKEN=...
AEGIS_TELEGRAM_TENANT=studio-a
AEGIS_TELEGRAM_MODE=polling
```

Telegram bot tokens are created with BotFather. Channels are optional; agent
plugins and MCP can be your first interface.

## Stop Or Remove

macOS:

```bash
~/.aegis/self-host/scripts/aegis-stop.sh
~/.aegis/self-host/scripts/aegis-stop.sh --remove
~/.aegis/self-host/scripts/aegis-stop.sh --purge
```

Windows:

```powershell
& "$HOME\.aegis\self-host\scripts\aegis-stop.ps1"
& "$HOME\.aegis\self-host\scripts\aegis-stop.ps1" -Remove
& "$HOME\.aegis\self-host\scripts\aegis-stop.ps1" -Purge
```

`--purge` / `-Purge` removes Docker volumes, including local database data.
If the helper script was not downloaded, use the CLI lifecycle commands instead:

```bash
aegis --root ~/.aegis/self-host stop
aegis --root ~/.aegis/self-host down
aegis --root ~/.aegis/self-host down --purge
```

## Repository Roles

| Repository | Visibility | Owns |
| --- | --- | --- |
| `HaloForgeAI/Aegis` | Private | Runtime source, Dockerfiles, release workflow, internal docs, implementation decisions |
| `HaloForgeAI/aegis-release` | Public | Public installers, compose template, release assets, checksums, install runbooks |
| `HaloForgeAI/aegis-site` | Public | Brand site, quickstart copy, SEO, Cloudflare Pages deployment |
| `HaloForgeAI/aegis-agent-plugins` | Public | Codex, Claude Code, and agent plugin distribution |

Do not hand-edit generated release assets here. CLI archives, the optional
Docker recovery archive, and `SHA256SUMS` should be produced by the private
Aegis release workflow, then mirrored into GitHub Releases in this repository.

## Public Launch Check

Maintainers can check the public gates with:

```bash
scripts/check-public-release.sh v0.1.2
```

The check verifies GitHub Release downloads, GHCR anonymous image access, the
Docker recovery archive, and the Cloudflare Pages custom domain. GHCR is a hard
public launch gate; the archive is checked as a backup asset, not as a substitute
for the official image path.

More detail lives in [docs/PUBLIC-RELEASE-RUNBOOK.md](docs/PUBLIC-RELEASE-RUNBOOK.md).
