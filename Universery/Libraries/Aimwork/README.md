# Libraries/Aimwork — third-party target engine (vendored, verbatim)

## Vendored sources (do NOT edit — re-fetch to update)

| What | Source | Version | License |
|---|---|---|---|
| Aimwork `src/*` (19 files) + `pesde.toml` + `README.md` | `github.com/Stefanuk12/aimwork` (NOT the older `Aiming` repo) | tree `db1ee50`, MIT | MIT |
| Trove (Aimwork's only runtime dep) | `github.com/Sleitnick/RbxUtil` `modules/trove/init.luau` | MIT | MIT |

Layout: `upstream/` mirrors the repo (`src/...`, `pesde.toml`, `README.md`);
`vendor/trove/init.luau` is the trove module (`@pkgs/trove`).
`loader.luau` (Universery code, NOT third-party) resolves the pesde-style
aliases (`@pkgs/*`, `@core/*`, `@modules/*`, `@types/*`, `@functions/*`,
`@patches`, `@self/*`) against embedded blobs and returns the live
`Aimwork` class. No fork, no in-source patches; the only compatibility
surface is the loader + `AimworkAdapter` state reporting.

## Known runtime risks (reported, not hidden)

1. Heavy Luau type syntax (`export type`, `::`, annotations) across ~1900
   lines — executor must parse it or the adapter reports NOT COMPATIBLE.
2. `PlayerTracker` calls `StarterGui:GetCore(...)` unguarded at construction;
   load failure degrades gracefully (built-in resolver continues).
3. `newproxy` (trove) must exist in the executor.
