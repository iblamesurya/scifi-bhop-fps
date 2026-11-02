---
tags: [tasks, log]
---
# Task Log

## TODO
- [x] Audit `--!strict` on line 1 across all `.luau` files — all compliant ([[Rules & Guardrails]])
- [ ] Audit `Instance.new` usage outside pooled/one-time setup paths
- [ ] Populate `assets/models/viewmodels/` (currently only `.gitkeep`)
- [ ] Populate `assets/audio/*` and `graphics/vfx_prefabs/`

## Decisions
- 2026-11-02 — Obsidian vault rooted at the project folder; notes live in `notes/`.
- 2026-11-02 — Replaced runtime `Instance.new` impact allocations in `PhantomMidway_ClientController.luau` with a pre-allocated 20-slot ring buffer pool (`IMPACT_POOL_SIZE = 20`) and moved all sound IDs into `AssetRegistry.Audio.Environment` to strictly obey `[[Rules & Guardrails]]`.

## Log
- 2026-11-02 — Created vault notes ([[00 Home]]).
- 2026-11-02 — Applied complete 10-phase AeroStrike Sky Island Lobby Rebuilder & Runtime Controller (`src/server/map/AeroStrike_Lobby_Rebuilder_And_Controller.server.luau`) across all 6 islands ([[Lobby & Match Flow]]).
- 2026-11-02 — Applied Phantom Midway 5v5 V2 Audit & Refactor (`src/server/map/PhantomMidway_V2_AuditFix.server.luau` + `src/client/graphics/PhantomMidway_ClientController.luau`): O(1) 3D spatial hash deduplication, OOB/target booth cleanup (122 OOB + 2 booths removed), top-preserving ground wall snap (221 walls), 105 tagged windows, 304 tagged wall reliefs, 12 symmetrical 180°-mirrored vehicles/bus-stops/planters, 48 soft lights, 1,274 shadow-culled micro-parts, and tactical callout/spawn-protection volumes.
