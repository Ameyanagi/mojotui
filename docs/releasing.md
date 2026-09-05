# Releasing

Mojotui uses an immutable source tag plus the shared
[`Ameyanagi/mojo-channel`](https://github.com/Ameyanagi/mojo-channel). Conda-forge
is a transitive dependency channel, not a requirement for publishing Mojotui.

1. Update the workspace, recipe, lockfile, changelog, compatibility, and
   security policy. Regenerate `pixi.lock` through Pixi; never edit it manually.
2. Run `pixi run --locked check`, `pixi run --locked package`, and
   `bash scripts/check-package-metadata.sh` from a clean release candidate.
3. Merge only after all three native source/package CI targets pass.
4. Create an annotated `vX.Y.Z` tag at the tested `main` commit. The release
   workflow checks the peeled target, `origin/main` ancestry, exact dependency
   metadata, and dated changelog before testing the source archive.
5. After the protected GitHub source release succeeds, dispatch the central
   channel workflow for repository `mojotui`, that immutable tag, and
   `publish=true`. Verify exact clean installs from all three subdirectories.

Never move a published tag or overwrite a channel artifact. A correction uses
a new patch version; `0.1.1` follows this rule because `0.1.0` was already
published with overly broad runtime metadata.

## Source archive handoff

Both the pull-request smoke workflow and the release workflow call
`scripts/source-artifact.sh` to create a single Git archive, compute its SHA-256,
verify the downloaded checksum, and extract the required source files. The
archive contains committed sources and no Git checkout metadata. Restoration
requires a fresh destination directory so stale sources cannot contaminate
the extracted artifact.

Every PR restores that artifact on Linux x86-64, Linux ARM64, and macOS ARM64,
installs the locked Pixi environment in the extracted directory, and runs
`pixi run --locked source-artifact-check`. That check precompiles the extracted
library with warnings as errors, then runs the package consumer in a fresh
directory against the resulting `.mojoc`, without importing checkout sources.
Releases additionally run the full source and Conda package checks before
publishing. `pixi run --locked source-artifact-test` tests the shared handoff,
including rejection of a corrupt checksum before any extraction.
