# Universery Architecture (map + migration plan)

## 1. Inventory (2026-10-03)

| File | Size | Role |
|---|---|---|
| `universal_aimbot_maclib.txt` | 222KB / 6419 lines | **LIVE artifact**: aimbot + ESP + SilentAim + MacLib UI, single executor file |
| `aimbot.txt` | 137KB | Aimbot source (rebuild input; currently DIVERGED from live) |
| `maclib_aimbot_ui.txt` | 46KB | UI source (rebuild input) |
| `universal_aimbot.txt` | 130KB | Older monolith copy (dead?) |
| `beforemethod.txt` | 129KB | Reference copy (dead?) |
| `exunys.txt` | 17KB | Original Exunys reference |
| `obsidian_aimbot_ui.txt` | 28KB | Dead Obsidian UI (MacLib migration done) |
| `maclib_ornek.txt` | 4KB | MacLib example |
| `UniversalToolkit/` | ~20 files, biggest 520 lines | SEPARATE older toolkit project (services-based). NOT Universery. Untouched. |
| `UniversalToolkit_Executor.txt` | 29KB | Its bundled output. Untouched. |

**Aimwork source: NOT PRESENT anywhere in the workspace.** Integration is
blocked on receiving it (see §7).

**Build process: NONE.** The live file is hand-merged. `Universery/Build.ps1`
is the first official builder (Phase 1: byte-identical reassembly proof).

**Deployment model: single-file executor execution** (`[string ""]`). There is
no `require()`; modular source MUST bundle to one file. Multi-file runtime
loading is rejected (fragile paths, slow, undebuggable in executors).

## 2. Monolith map (live file)

| Lines | Block | Key contents |
|---|---|---|
| 1-131 | Boot/UI shell | MacLib load, Window, TabGroup, 5 tabs, MakeSection, Aim() accessor, Notify |
| 132-442 | Aimbot base | Luraph shims, cached globals, services, methods, state tables, InputConflictController |
| 443-727 | Environment | Whole settings literal (Settings/FOV/Network/ESP/SilentAim/TeamResolver) + alias |
| 728-2600 | Aimbot core | Team resolver (~300 lines), validation/scoring/hysteresis, prediction v2, aim loop, smoothing |
| 2601-3942 | ESP engine | Body cache, screen-bounds, box/3D/corner, tracer, skeleton (rig Motor6D), health, name, chams, fade, ESPRefresh |
| 3943-3958 | Methods | Typing/input guards |
| 3959-4664 | SilentAim | Resolver/validator/FOV/prediction/hook engine (camera-read hook + HookHits), GetSilentInfo |
| 4665-4917 | API/Exit | GetTargetInfo/Diagnostics, Exit/Panic/Restart, setmetatable |
| 4918-4949 | Auto-start | PreviousInstance handoff, Load(), BuildAimbot() call |
| 4950-6419 | UI build | Write()+Syncers chain, Aimbot/ESP/SilentAim/Debug/Settings tabs, resets, debug loop, build tag |

Function scopes containing locals: `BuildAimbot()` (~170 regs), UI `do` block (~47),
`BuildESPTab()` / `BuildSilentTab()` (own helpers). Chunk peak 58/200.

Cross-cutting shared systems (used by 2+ features):
`IsSameTeam`/`ResolveTeamInfo`, `CheckVisibilityCached`, `GetCharacterData`,
`PingState` (+Effective chain), `ESPProject`, `InputConflictController`,
`ServiceConnections`, `Environment`, `GetSilentInfo`/`GetTargetInfo`.

## 3. Target tree (status-tagged)

```text
Universery/
├── ARCHITECTURE.md            [THIS FILE]
├── Build.ps1                  [DONE: manifest concat + byte-proof]
├── dist/                      [BUILD OUTPUT - never edit]
├── src/parts/                 [PHASE-1: verbatim slices, byte-proven]
├── Core/
│   ├── Services.lua           [DONE]
│   ├── Scheduler.lua          [DONE - adoption milestone M2]
│   ├── ConnectionManager.lua  [DONE - adoption milestone M2]
│   └── Runtime.lua / State.lua / Signals.lua / CleanupManager.lua  [PLANNED M2]
├── Config/
│   └── Manager.lua            [DONE: facade over Environment+Write, versioned]
│   └── Defaults/Serializer/Migrations  [PLANNED: Manager.Migrate covers first]
├── Compatibility/
│   └── Executor.lua           [DONE: capability registry]
├── Debug/
│   └── Logger.lua             [DONE]
│   └── Diagnostics.lua        [PLANNED M2]
├── Shared/                    [PLANNED M2: TeamResolver, TargetUtils, Prediction, Math, Drawing, Input, Camera, Character]
├── Features/
│   ├── SilentAim/
│   │   ├── AimworkAdapter.lua [DONE: seam, state NOT INSTALLED]
│   │   └── Adapters/Registry.lua [DONE]
│   └── Aimbot|ESP|Movement|... [PLANNED M2-M3 - migrate, do NOT invent features]
├── Libraries/
│   └── Aimwork/               [BLOCKED: source not in workspace]
└── UI/                        [PLANNED M2: split 18_UIBuild by tab]
```

Deliberate deviations from the sketched tree: no Movement/Players/World/
Performance/Visuals features (they do not exist; placeholders banned). No
`Main.lua`/`Loader.lua` yet (they arrive with the registry phase; the dist
file itself is the current entry). `UniversalToolkit/` is out of scope.

## 4. Module conventions (binding)

1. One file = one `do ... end` scope at bundle time (register hygiene).
2. Sharing ONLY via `Universery.*` registry (one chunk local, declared first).
   No cross-module `local` visibility, no `_G/getgenv` feature state.
3. Modules: `Universery.X = {}` + `function Universery.X.F()` + `Init/Start/
   Stop/Destroy` where lifecycle applies. Third-party libs keep their own API,
   managed via adapters.
4. Dependency direction: Features -> Shared -> Core. Shared never imports
   Features. No cycles (bundler manifest order enforces).
5. Behavior preservation: refactor slices, never rewrite logic; verify with
   balance/register/chain scripts after every milestone.

## 5. Phases

- **M1 (this change):** map + mechanical split (byte-proven) + builder +
  foundation modules (Executor/Logger/Scheduler/ConnectionManager/Config) +
  Aimwork seam. Live artifact untouched.
- **M2:** registry transform (module `local`s -> `Universery.*`), wire
  foundation modules (Executor probes replace scattered checks; Logger
  replaces dprint/warn; Scheduler adopts scan loops), split UI by tab.
- **M3:** extract Shared/* (TeamResolver first), then Features/*.
- **M4:** Aimwork source drop-in + AimworkAdapter live + fire-adapter
  registry per game. SilentAim fire integration per game adapter.
- **M5:** dead-code deletion (only with owner approval), final report.

## 6. Dead-code proposal (DELETE ONLY WITH APPROVAL)

`obsidian_aimbot_ui.txt` (dead post-MacLib), `universal_aimbot.txt`,
`beforemethod.txt` (stale copies), `maclib_ornek.txt` (example). Keep
`exunys.txt`, `aimbot.txt`, `maclib_aimbot_ui.txt` until rebuild flow is
replaced by Build.ps1 (aimbot.txt is DIVERGED - do not rebuild from it).

## 7. Blockers

1. **Aimwork source: RESOLVED.** Vendored verbatim (`upstream/`, tree
   `db1ee50`) + trove (`vendor/`, RbxUtil, MIT). Loader + live
   `AimworkAdapter` (headless FOV, per-scan sync, post-validation) wired
   into `SilentAim.Scan` with built-in fallback. Adapter state visible in
   debug (`AW:` line). Parse/compat risk documented, degrades gracefully.
2. **Target game: open.** FireAdapter = generic hook engine (extracted from
   monolith, registry-isolated per-game adapters). No game hardcoded.
3. Rebuild inputs (`aimbot.txt` + `maclib_aimbot_ui.txt`) diverged from live;
   treat the trunk (`universal_aimbot_maclib.txt`) + `src/parts` as truth.
   From M2a on, the runnable artifact is `Universery/dist/` output; the
   trunk file is source. Stable rollback: `universal_aimbot_maclib.espv5.bak.txt`.

## 8. M2a status (registry seed + first extractions)

- `local Universery = {}` registry first in dist; new modules wrapped in
  `do/end` by Build.ps1 v2 (manifest: registry + 4 modules + 10 raw parts).
- Extracted: `Features/SilentAim/FireAdapter.lua` (hook engine, own registry),
  live `AimworkAdapter` + `Libraries/Aimwork/loader.luau` + generated blobs.
- Monolith rewired to `Universery.*` (~25 call sites, no logic changes).
- Verified: dist code balance 0, chunk ~58 / func ~170, all chains green.
- Deferred to M2b: Shared/TeamResolver extraction, UI tab split, Scheduler/
  ConnectionManager/Config adoption, `Main.lua`/`Loader.lua`, foundation
  modules (currently return-style, not yet bundled).

## 9. M2b status (Shared/TeamResolver + UI split + dist entrypoint)

- Shared/TeamResolver.lua extracted verbatim (660 lines, dep-injected);
  monolith keeps 8 one-line delegates (zero call-site churn).
- UI build split into 6 tab files (18a-f); manifest updated.
- Runnable entrypoint is now Universery/dist/Universery.lua (Phase 48);
  trunk file is source-only (needs bundled registry).
- dist built TWICE with identical hash (no duplication on rebuild).
- Dead files moved to Universery/_archive/ (obsidian/universal_aimbot/
  beforemethod/maclib_ornek); aimbot.txt + maclib_aimbot_ui.txt + exunys kept.
- Deferred to M3: Shared/Prediction unify, Scheduler/ConnectionManager/Config
  adoption, Main/Loader, foundation return-style modules bundling.
