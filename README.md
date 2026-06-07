# Aegis Public Release

Public distribution surface for Aegis, the HaloForgeAI AI chief-of-staff.

This repository is intentionally small. It does not mirror the private Aegis
source tree. It hosts the public onboarding layer: install scripts, compose
templates, checksums, and GitHub Releases that can be downloaded by users who do
not have access to `HaloForgeAI/Aegis`.

## Repository Roles

| Repository | Visibility | Owns |
| --- | --- | --- |
| `HaloForgeAI/Aegis` | Private | Runtime source, Dockerfiles, release workflow, internal docs, implementation decisions |
| `HaloForgeAI/aegis-release` | Public | Public installer, public compose template, release assets, checksums, install runbooks |
| `HaloForgeAI/aegis-site` | Public | Brand site, public quickstart copy, SEO, Cloudflare Pages deployment |
| `HaloForgeAI/aegis-agent-plugins` | Public | Codex, Claude Code, and agent plugin distribution |

Do not hand-edit generated release assets here. CLI archives and `SHA256SUMS`
should be produced by the private Aegis release workflow, then mirrored into
GitHub Releases in this repository.

## Current Launch Target

The intended public install shape is:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | bash
```

CLI only while GHCR is still private:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | bash -s -- --no-docker
```

Windows PowerShell:

```powershell
iwr https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.ps1 -OutFile install-aegis.ps1
powershell -ExecutionPolicy Bypass -File .\install-aegis.ps1
```

The installer expects public assets for the chosen `AEGIS_VERSION`.

```bash
AEGIS_VERSION=v0.1.1 bash install.sh
```

Required public gates before promoting this as generally available:

- `docker pull ghcr.io/haloforgeai/aegis:<tag>` works anonymously.
- The matching `aegis-cli-<tag>-aarch64-apple-darwin.tar.gz` release asset is
  attached to this public repository.
- The matching `aegis-cli-<tag>-x86_64-pc-windows-msvc.zip` release asset is
  attached to this public repository.
- `SHA256SUMS` covers every public CLI archive.

## Compose Only

For users who want to inspect and run the public Docker stack manually:

```bash
mkdir -p ~/.aegis/self-host
cd ~/.aegis/self-host
curl -fsSLO https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/compose/aegis.compose.yml
curl -fsSLO https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/.env.example
cp .env.example .env
docker compose --env-file .env -f aegis.compose.yml up -d
```

Generate secrets locally and keep them out of Git:

```bash
printf 'AEGIS_AUTH_SECRET=%s\n' "$(openssl rand -hex 32)" >> .env
```

## Maintainer Flow

1. Change runtime behavior in `HaloForgeAI/Aegis`.
2. Tag Aegis, for example `v0.1.1`.
3. Run the private Aegis release workflow.
4. Confirm the workflow pushed `ghcr.io/haloforgeai/aegis:<tag>`.
5. Confirm the workflow mirrored CLI assets and checksums to this repository's
   public GitHub Release.
6. Test anonymous install from a clean machine before changing the brand site
   quickstart from "launch target" to "available".

More detail lives in [docs/PUBLIC-RELEASE-RUNBOOK.md](docs/PUBLIC-RELEASE-RUNBOOK.md).

## Public Launch Check

Maintainers can check the public gates with:

```bash
scripts/check-public-release.sh v0.1.1
```

This verifies public GitHub Release downloads, GHCR anonymous token access, and
the Cloudflare Pages custom domain.
