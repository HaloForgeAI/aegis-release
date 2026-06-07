# Public Release Runbook

## Goal

Make Aegis installable by users who cannot access the private source repository.

The public release is complete only when all of these work anonymously:

```bash
docker pull ghcr.io/haloforgeai/aegis:<tag>
curl -I https://github.com/HaloForgeAI/aegis-release/releases/download/<tag>/SHA256SUMS
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | AEGIS_VERSION=<tag> bash
```

## Source Release

1. In `HaloForgeAI/Aegis`, update runtime, docs, and release notes.
2. Tag the source repository.
3. Run the private `Release` workflow.
4. Confirm it builds:
   - `ghcr.io/haloforgeai/aegis:<tag>`
   - `aegis-cli-<tag>-aarch64-apple-darwin.tar.gz`
   - `aegis-cli-<tag>-x86_64-pc-windows-msvc.zip`
   - `SHA256SUMS`

## Public Mirror

The private workflow should upload the CLI archives and checksums to this
repository's GitHub Release with the same tag. That workflow needs a secret with
contents write permission to `HaloForgeAI/aegis-release`, for example:

```text
AEGIS_PUBLIC_RELEASE_TOKEN
```

Do not use a token that grants more access than needed.

## GHCR Visibility

The container can be built from a private source repository and still be public
through GitHub Container Registry package visibility. After the first package is
published, set the package visibility to Public and confirm anonymous pull.

Anonymous verification:

```bash
docker logout ghcr.io || true
docker pull ghcr.io/haloforgeai/aegis:<tag>
```

If anonymous pull asks for credentials, the package is still private or inherited
private permissions.

## Website Update

Only after the anonymous checks pass should `HaloForgeAI/aegis-site` promote the
quickstart from "launch target" to "available".
