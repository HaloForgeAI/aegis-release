# Ownership

`HaloForgeAI/aegis-release` is the public distribution layer for Aegis.

It owns:

- Native install scripts.
- Public GitHub Release assets.
- Checksums.
- Public install and release runbooks.

It does not own:

- Aegis runtime source.
- Server/API behavior.
- Gateway, worker, channel, MCP, Talent, or UI implementation.
- Internal product decisions.

Source changes land in `HaloForgeAI/Aegis` first. Generated native bundles and `SHA256SUMS` are produced by the private release workflow and mirrored here.
