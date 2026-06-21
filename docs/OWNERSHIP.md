# Ownership

This repository is public because release assets must be reachable without
access to the private source repository.

## Edit Here

- Public native app release notes.
- Public checksum and release asset verification docs.
- Public release smoke scripts under `scripts/`.
- GitHub Release notes for public assets.

## Do Not Edit Here

- Rust, TypeScript, Dockerfile, database, gateway, worker, channel, MCP, and UI
  implementation logic. Change those in `HaloForgeAI/Aegis`.
- Generated native app assets. They are built by the `HaloForgeAI/Aegis`
  release workflow.
- Brand site copy or SEO metadata. Change those in `HaloForgeAI/aegis-site`.
- Codex, Claude Code, or generic agent plugin packages. Change those in
  `HaloForgeAI/aegis-agent-plugins`.

## Sync Direction

The private Aegis source repository is allowed to reference this public release
repository as a submodule for operator convenience. This repository must not
reference the private source repository as a submodule, because public users must
be able to clone it without private credentials.

Expected layout inside the private source checkout:

```text
public/
├── aegis-release -> https://github.com/HaloForgeAI/aegis-release.git
└── aegis-site    -> https://github.com/HaloForgeAI/aegis-site.git
```

Runtime source changes flow from `HaloForgeAI/Aegis` into public release assets.
Public release copy fixes can be made here first, then reflected back into the
private source docs and release workflow when they change behavior.
