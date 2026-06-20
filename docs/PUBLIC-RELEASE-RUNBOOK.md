# Public Release Runbook

Use this after the private Aegis source release has produced native bundles and mirrored them into this repository.

## Required Assets

For tag `<tag>`, the public release must contain:

- `aegis-native-<tag>-x86_64-unknown-linux-gnu.tar.gz`
- `aegis-native-<tag>-aarch64-apple-darwin.tar.gz`
- `aegis-native-<tag>-x86_64-pc-windows-msvc.zip`
- `SHA256SUMS`

## Public Checks

```bash
scripts/check-public-release.sh <tag>
```

Then smoke install on clean machines:

```bash
curl -fsSL https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.sh | AEGIS_VERSION=<tag> bash
aegis --root ~/.aegis/profiles/release status
aegis --root ~/.aegis/profiles/release onboarding doctor
```

Windows:

```powershell
$env:AEGIS_VERSION = "<tag>"
iwr https://raw.githubusercontent.com/HaloForgeAI/aegis-release/main/install.ps1 -OutFile install-aegis.ps1
powershell -ExecutionPolicy Bypass -File .\install-aegis.ps1
& "$HOME\.aegis\bin\aegis.exe" --root "$HOME\.aegis\profiles\release" status
```

## Release Notes

Release notes should say which native bundles are available, how to verify checksums, and which Aegis version they contain. Do not point users at private source artifacts.
