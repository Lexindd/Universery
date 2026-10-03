# src/parts — Phase-1 mechanical split of universal_aimbot_maclib.txt.

Each file is a VERBATIM byte slice of the trunk artifact, in manifest
(execution) order. Regenerate any time with: python tools/split.py
(script asserts contiguous tiling + byte-identical reassembly).
Ranges below track trunk HEAD (M2a); the split script is marker-driven so
ranges follow the code automatically.

| Part | M2a lines | Future module(s) |
|---|---|---|
| 00_Boot.luau | 1-131 | Main/Loader + UI/Init shell (MacLib, Window, Tabs, MakeSection, Aim, Notify) |
| 10_AimbotBase.luau | 132-442 | Core/Runtime + Compatibility (Luraph shims, caches, services, conflict controller) |
| 11_Environment.luau | 443-727 | Config/Defaults (the whole Environment literal: Settings, FOV, ESP, SilentAim, TeamResolver) + alias |
| 12_AimbotCore.luau | 728-2600 | Features/Aimbot/* + Shared/TargetUtils (validation, scoring, scan, prediction, loops) |
| 13_ESP.luau | 2601-3942 | Features/ESP/* (bounds, box, tracer, skeleton, health, name, chams, fade, ESPRefresh) |
| 14_Methods.luau | 3943-3958 | Features/Aimbot/Controller (typing/input guards) |
| 15_SilentAim.luau | 3959-4599 | Features/SilentAim/* (controller, resolver, FOV, prediction, consult; hook engine moved to FireAdapter module) |
| 16_APIExit.luau | 4600-4852 | Core/CleanupManager (Exit/Panic/Restart) + public API surface |
| 17_AutoStart.luau | 4853-4886 | Main (boot call) |
| 18_UIBuild.luau | REMOVED M2b | split into 18a-f below |
| 18a_UIInfra.luau | 4246-4444 | UI/Init infra (El, syncer, Write, maps, PushAllToAimbot) |
| 18b_TabAimbot.luau | 4445-4984 | UI/Tabs/Aimbot.lua (aimbot + filters + smoothing + targeting + prediction + utility) |
| 18c_TabESP.luau | 4985-5344 | UI/Tabs/ESP.lua (BuildESPTab) |
| 18d_TabSilent.luau | 5345-5529 | UI/Tabs/SilentAim.lua (BuildSilentTab) |
| 18e_TabDebug.luau | 5530-5617 | UI/Tabs/Debug.lua (target + network + silent labels + loop) |
| 18f_TabSettings.luau | 5618-end | UI/Tabs/Settings.lua (menu + config + about + PushAll + build tag) |

Rule: do NOT hand-edit logic here to "improve" things. Trunk edits go to
universal_aimbot_maclib.txt, then re-run split + build. Refactors move code
into real modules (never leave improved copies in both places).
