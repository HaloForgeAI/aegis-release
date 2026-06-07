# Ownership Map

This repository is public because install and release artifacts must be
reachable without access to the private source repository.

## Edit Here

- Public install scripts: `install.sh`, `install.ps1`.
- Public compose template: `compose/aegis.compose.yml`.
- Public launch and verification docs.
- GitHub Release notes for public assets.

## Do Not Edit Here

- Rust, TypeScript, Dockerfile, database, gateway, worker, channel, MCP, and UI
  implementation logic. Change those in `HaloForgeAI/Aegis`.
- Generated CLI archives. They are built by `HaloForgeAI/Aegis` release workflow.
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
Public install usability fixes can be made here first, then reflected back into
the private source docs and release workflow when they change behavior.
