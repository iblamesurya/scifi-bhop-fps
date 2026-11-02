# Cross-Agent Contracts

Single source of truth for every interface that **more than one issue touches**.
Agents build against these contracts so work can run in parallel. If you need to
change a contract, open a PR that edits **only this file** first and tag the issues
it affects. Do not silently deviate.

All rules in `AGENTS.md` still apply (`--!strict`, no `Instance.new` in loops, no
`rbxassetid://` in gameplay code, buffers for high-frequency remotes, no `Tool`).

---

## 1. Player attributes (server writes, everyone reads)

| Attribute | Type | Owner (writer) | Meaning |
|---|---|---|---|
| `Team` | `string` `"Alpha"` / `"Bravo"` / `""` | TeamService | `""` = lobby / unassigned |
| `Kills` `Deaths` `Assists` | `number` | CombatValidator / MatchService | per-match counters, reset each match |
| `Ping` | `number` (ms) | ScoreboardService | server-measured, updated 1 Hz |
| `InArena` | `boolean` | MatchService | already exists |
| `SelectedWeapon` | `string` | LoadoutService | already exists |
| `EquippedWeapon` | `string` | InventoryService | weapon currently in hand (drives 3P model) |
| `ReserveAmmo` `MagAmmo` | `number` | LoadoutService | server-authoritative ammo, HUD reads these |
| `IsAlive` | `boolean` | MatchService | false while dead / spectating |
| `Level` `XP` | `number` | XPService | persisted via ProfileService |

## 2. Match state (ReplicatedStorage attributes)

Set on `ReplicatedStorage` by **RoundService only**.

| Attribute | Type | Values |
|---|---|---|
| `MatchPhase` | `string` | `Lobby` `Warmup` `Buy` `Live` `RoundEnd` `MatchEnd` |
| `RoundNumber` | `number` | 1-based |
| `PhaseEndsAt` | `number` | `Workspace:GetServerTimeNow()` timestamp |
| `ScoreAlpha` `ScoreBravo` | `number` | rounds won |
| `RoundsToWin` | `number` | default 13 (from `MatchConfig`) |

Clients derive timers from `PhaseEndsAt` - never from a server tick.

## 3. Remotes

Names live in `AssetRegistry.NetworkEvents` (the only place strings are defined).
Packet encode/decode helpers live in `src/shared/network/EventPackets.luau`
(created by issue F0). All high-frequency remotes use `buffer`.

| Remote | Type | Direction | Packet layout |
|---|---|---|---|
| `KillFeedEvent` | RemoteEvent | S -> all C | `u32 killerUserId, u32 victimUserId, u8 weaponNumericId, u8 flags` (bit0 headshot, bit1 wallbang, bit2 noscope, bit3 airborne, bit4 grenade, bit5 melee) |
| `DamageIndicatorEvent` | UnreliableRemoteEvent | S -> victim C | `f32 ox, f32 oy, f32 oz` (attacker world pos) `u8 damage u8 flags` |
| `DeathInfoEvent` | RemoteEvent | S -> victim C | `u32 killerUserId u8 weaponNumericId u8 flags f32 killerHealthLeft` |
| `RoundEventRemote` | RemoteEvent | S -> all C | `u8 eventType` (1 round start, 2 round end, 3 match end, 4 match point) `u8 winnerTeam u8 scoreA u8 scoreB` |
| `GrenadeThrowRemote` | RemoteEvent | C -> S | `f64 t, f32x3 origin, f32x3 velocity, u8 grenadeId` |
| `GrenadeDetonateEvent` | RemoteEvent | S -> all C | `f32x3 pos, u8 grenadeId, u32 ownerUserId` |
| `MeleeSwingRemote` | RemoteEvent | C -> S | `f64 t, f32x3 origin, f32x3 dir, u8 attackType` |
| `PurchaseRequest` | RemoteEvent | C -> S | already defined by `EconomyPacket` - do not change |
| `SettingsSync` | RemoteEvent | C -> S | `string` JSON is allowed (low frequency, saved to profile) |

`weaponNumericId` = `WeaponData[...].WeaponId`.

## 4. Server-side Lua hooks (BindableEvents on `ServerScriptService.Server`)

Created by F0 inside `CombatValidator`; consumed by Round/XP/Achievement services.

- `CombatValidator.OnDamage(attacker, victim, amount, weaponId, flags)`
- `CombatValidator.OnKill(attacker, victim, weaponId, flags, assistants)`
  - `flags` uses the same bitfield as `KillFeedEvent`.
  - `assistants` = `{ Player }` (>= 25 damage within 5 s of the kill).

## 5. Module ownership (to avoid merge conflicts)

One owner per file. If your task needs an edit in a file you don't own, make the
**smallest possible edit** (a hook call or exported function), reference the owning
issue in the PR, and rebase onto the owner's latest main.

| Area | Files | Owning issue |
|---|---|---|
| Combat events | `src/server/combat/CombatValidator.luau`, `src/shared/network/EventPackets.luau` | F0 |
| Ammo / reload | `src/server/combat/LoadoutService.luau` | C1 |
| Inventory / hotkeys | `src/client/combat/InventoryController.luau`, `src/server/combat/InventoryService.luau` | C2 |
| Grenades | `src/server/combat/GrenadeService.luau`, `src/client/combat/GrenadeController.luau` | C3 |
| Melee | `src/server/combat/MeleeService.luau`, `src/client/combat/MeleeController.luau` | C4 |
| Teams | `src/server/match/TeamService.luau` | M1 |
| Round loop | `src/server/match/RoundService.luau`, `src/shared/configs/MatchConfig.luau` | M2 |
| Scoreboard UI | `src/client/ui/ScoreboardApp.luau` | U1 |
| Killfeed UI | `src/client/ui/KillfeedApp.luau` | U2 |
| Damage feedback UI | `src/client/ui/DamageFeedbackApp.luau` | U3 |
| Death screen UI | `src/client/ui/DeathScreenApp.luau` | U4 |
| Buy menu UI | `src/client/ui/BuyMenuApp.luau` | U5 |
| Settings / pause | `src/client/ui/MenuApp.luau`, `src/client/settings/SettingsStore.luau` | U6 |
| Input abstraction / touch | `src/client/input/*` | U7 |
| 3P weapons | `src/server/character/CharacterWeaponService.luau` | T1 |
| 3P animation | `src/client/character/ThirdPersonAnimator.luau` | T2 |
| Audio | `src/client/audio/FootstepController.luau`, `AnnouncerController.luau`, `WorldAudioController.luau` | A1 / A2 / A3 |
| Profile / XP | `src/server/profile/*` | P1 / P2 |

`src/client/init.client.luau` and `src/server/init.server.luau` are **shared
bootstrappers**: only add one `requireClientModule` / `requireServerModule` line and
one `safeInit` line. Keep additions at the end of the list to minimise conflicts.

## 6. Definition of done (every issue)

1. `--!strict` on line 1; `selene src/` and `stylua --check src/` pass.
2. No new `Instance.new` inside RenderStepped / fire loops (pool instead).
3. No hardcoded `rbxassetid://`; use `AssetRegistry`, `animations/registry`, `LightingProfile`.
4. Verified in Studio (Play Solo) with zero new console errors; note what you tested in the PR.
5. Matching note in `notes/` updated; one line appended to `notes/Task Log.md`.
6. PR description contains `Closes #<issue>` and a short test plan.
7. Only files listed in the issue's **Owned files** are changed, except minimal hook edits.
