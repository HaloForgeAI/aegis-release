# Aegis Public Release

Public native application assets for Aegis, the HaloForgeAI personal AI
assistant hub.

This repository is the user-facing distribution layer. The private source repo
builds native apps and mirrors public release assets here.

## Install Aegis

Download the latest release from
[`HaloForgeAI/aegis-release`](https://github.com/HaloForgeAI/aegis-release/releases)
and choose the app for your platform.

| Platform | Primary asset | Notes |
| --- | --- | --- |
| macOS Apple Silicon | `Aegis-<version>-macos-arm64.dmg` | Drag `Aegis.app` into Applications. |
| Windows x64 | `Aegis-<version>-windows-x64.msix` | Use the MSIX package when signed. Portable zip is for trusted testing only. |
| iPhone / iPad | TestFlight or signed `Aegis-<version>-ios.ipa` | IPA export requires Apple signing/provisioning. |
| Android | signed `Aegis-<version>-android.apk` or `Aegis-<version>-android.aab` | APK is for direct install; AAB is for Play-style distribution. |

Verify `SHA256SUMS` before installing when it is attached to the release.
Public release checks expect signed platform assets. Unsigned build artifacts
belong in workflow runs, not user-facing GitHub Releases.

## Advanced Operator Tools

CLI, MCP, and agent plugins remain supported for advanced operators after Aegis
Core is running through the desktop app or another owner-controlled Core.

## Network Access

Mobile apps and agent plugins need a reachable Aegis Core URL. Choose the
transport intentionally:

- local-only for same-machine desktop use;
- LAN for trusted home/lab networks;
- Tailscale Serve for private owner-device access across networks;
- Cloudflare Tunnel for stable public HTTPS hostnames and webhook callbacks;
- public host/VPS only with hardening, backups, TLS, and Aegis auth.

Do not expose an unauthenticated Aegis Core.

## Repository Roles

| Repository | Visibility | Owns |
| --- | --- | --- |
| `HaloForgeAI/Aegis` | Private | Runtime source, Core, Gateway, worker, native apps, canonical docs, release workflow |
| `HaloForgeAI/aegis-release` | Public | Public native app assets, checksums, release notes, minimal install guidance |
| `HaloForgeAI/aegis-site` | Public | Brand site, quickstart copy, SEO, Cloudflare Pages deployment |
| `HaloForgeAI/aegis-docs` | Public | Formal user manual |
| `HaloForgeAI/aegis-agent-plugins` | Public | Codex, Claude Code, and agent plugin distribution |

Do not hand-edit generated release assets here. DMG, MSIX, APK, AAB, IPA,
portable fallbacks, and `SHA256SUMS` should be produced by the private Aegis
release workflow, then mirrored into GitHub Releases in this repository.

## Public Release Check

Maintainers can check the public gates with:

```bash
scripts/check-public-release.sh v0.1.5
```

The check verifies native app downloads, checksums, and the public brand site.
It expects a signed Android APK/AAB and signed iOS IPA by default. Set
`AEGIS_EXPECT_IOS_IPA=0` only when the iOS path is TestFlight-only for that
specific release.
