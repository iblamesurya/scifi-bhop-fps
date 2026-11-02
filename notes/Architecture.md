---
tags: [architecture]
---
# Architecture — The 4 Pillars
Synced into Studio by `default.project.json` (Rojo). See [[Rules & Guardrails]] for the separation rules.

| Pillar | Folder | Lands in Roblox at |
|---|---|---|
| 1. Models / Audio / Sprites | `assets/` | `ReplicatedStorage.Assets.*`; maps → `Workspace` |
| 2. Animations | `animations/registry` | `ReplicatedStorage.Animations.Registry` |
| 3. Graphics | `graphics/` | `ReplicatedStorage.Graphics.{Materials,Presets,VFXPrefabs}` |
| 4. Gameplay logic | `src/` | client → `StarterPlayerScripts.Client`, server → `ServerScriptService.Server`, shared → `ReplicatedStorage.Shared` |

## Single sources of truth
- Assets (models, audio, sprites): `src/shared/configs/AssetRegistry.luau`
- Animations: `animations/registry/init.luau`
- Lighting / post-processing / FOV: `graphics/presets/LightingProfile.luau`

## Code layout
- **Client**: `movement/`, `combat/`, `viewmodel/`, `graphics/`, `audio/`, `ui/` (HudApp, LobbyApp, CrosshairModule)
- **Server**: `combat/` (HitboxHistory, CombatValidator, LoadoutService), `match/MatchService`, `map/ArenaGenerator` + lobby controller script, `economy/EconomyManager`, `character/CharacterService`, `replication/StanceReplicator`
- **Shared**: `configs/`, `math/` (Spring, QuakeMath), `network/` (ShotPacket, EconomyPacket), `weapons/WeaponBuilder`

## Server boot order (`src/server/init.server.luau`)
HitboxHistory → CombatValidator → StanceReplicator → EconomyManager → ArenaGenerator → MatchService. Each runs via a `safeInit` (`task.spawn` + `pcall`) so remotes exist before clients `WaitForChild`.

Related: [[Movement]], [[Combat & Networking]], [[Lobby & Match Flow]]
