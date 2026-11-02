# Agent Workboard

Generated from the GitHub issue set. Pick **one issue**, work only in its owned files, read `docs/CONTRACTS.md` first.

## How parallel work is organised

- **Waves:** wave 0 issues have no hard dependencies and can all start now. Wave N starts when its hard dependencies are merged. Soft dependencies never block: build against the mocks in `docs/CONTRACTS.md`.
- **Lanes:** each lane owns disjoint files (see CONTRACTS.md section 5), so lanes run concurrently with minimal merge conflicts.
- **Labels:** `agent-ready` = start now, `blocked` = waiting on a hard dependency, `needs-human` = requires a person.
- **Claiming:** comment `claiming` on the issue and assign yourself; one issue per branch `issue-<n>-<slug>`; remove `blocked` when dependencies merge.

## Issue index

| Code | Issue | Lane | Priority | Wave | Hard deps |
|---|---|---|---|---|---|
| F0 | #2 Combat event emitters: kill feed, damage direction, death info, kill/damage hooks | infra | P0 | 0 | - |
| I1 | #3 CI: GitHub Actions for selene, stylua, rojo build | infra | P0 | 0 | - |
| I3 | #4 Unit tests for pure modules (QuakeMath, ShotPacket, EconomyPacket, EventPackets) | infra | P1 | 0 | - |
| I4 | #5 Server-side movement validation (speed, teleport, fly, noclip) | infra | P1 | 0 | - |
| I5 | #6 Audit and remove runtime Instance.new in hot paths (pooling pass) | infra | P1 | 0 | - |
| C1 | #7 Server-authoritative reserve ammo, tactical/empty reload, and ammo attributes | combat | P0 | 0 | - |
| C2 | #8 Weapon slots and inventory: 1 primary, 2 secondary, 3 knife, 4 grenade, Q swap, wheel | combat | P0 | 1 | C1 |
| C3 | #9 Grenades: projectile physics, fuse, blast radius, line-of-sight falloff | combat | P0 | 2 | C2 |
| C4 | #10 Melee: KA-BAR and bat swings, backstab, knockback, MeleeCooldown | combat | P0 | 2 | C2 |
| C5 | #11 Weapon-specific behaviour: sniper scope, shotgun pellets, bolt/pump cycle, spread bloom | combat | P1 | 0 | - |
| M1 | #12 Team service: Alpha/Bravo assignment, balancing, friendly-fire rule | match | P0 | 0 | - |
| M2 | #13 Round loop state machine: warmup, buy, live, round end, first to 13 | match | P0 | 1 | M1 |
| M3 | #14 Spectate mode and death camera | match | P0 | 2 | M2 |
| M4 | #15 Late join, disconnect, AFK and forfeit handling | match | P1 | 2 | M2 |
| M5 | #16 Match summary data: MVP, stats and return-to-lobby flow | match | P1 | 2 | M2 |
| U1 | #17 Scoreboard (hold Tab): teams, K/D/A, ping, credits, top speed | ui | P0 | 0 | - |
| U2 | #18 Killfeed: sliding kill notifications with weapon icon and flags | ui | P0 | 0 | - |
| U3 | #19 Damage direction indicator, low-health vignette and hit flash | ui | P0 | 0 | - |
| U4 | #20 Death screen: killed-by card, weapon, killer health and respawn timer | ui | P1 | 0 | - |
| U5 | #21 Buy menu (B): weapons, armor, utility with credits and refunds | ui | P0 | 0 | - |
| U6 | #22 Pause/Settings menu: sensitivity, FOV, volumes, crosshair, keybinds, accessibility | ui | P0 | 0 | - |
| U7 | #23 Mobile touch and gamepad support via an input abstraction layer | ui | P0 | 0 | - |
| U8 | #24 Round HUD: timer, team score, phase banners, match point | ui | P0 | 0 | - |
| U9 | #25 Minimap and callout labels | ui | P2 | 0 | - |
| U10 | #26 Post-match summary screen with MVP and rematch/lobby buttons | ui | P1 | 3 | M5 |
| U11 | #27 Weapon icons rendered from CAD models (replace rbxassetid://0 sprites) | ui | P1 | 0 | - |
| T1 | #28 Third-person: weld equipped weapon worldmodels to character hands | character | P0 | 2 | C2 |
| T2 | #29 Third-person animation: slide, air-strafe lean, aim pitch, hold poses | character | P1 | 3 | T1 |
| T3 | #30 Team nametags, enemy outlines on spot, and hit highlights | character | P1 | 0 | - |
| T4 | #31 Death effects, hit reactions and footstep dust at speed | character | P2 | 0 | - |
| A1 | #32 Material-based footsteps for self and other players | audio | P1 | 0 | - |
| A2 | #33 Announcer and stingers: round start, match point, streaks, victory/defeat | audio | P2 | 0 | - |
| A3 | #34 Positional weapon audio for other players: distance falloff, indoor reverb, suppression | audio | P1 | 0 | - |
| P1 | #35 ProfileService: persistent player profile (settings, stats, XP, unlocks) | progression | P1 | 0 | - |
| P2 | #36 XP, levels and rewards | progression | P1 | 1 | P1 |
| P3 | #37 Weapon skins: inventory, equip UI and application to viewmodel/worldmodel | progression | P2 | 1 | P1 |
| P4 | #38 Achievements and daily challenges (speed and movement themed) | progression | P2 | 1 | P1 |
| P5 | #39 Practice range / tutorial: bhop course, slide gaps, target dummies | progression | P1 | 0 | - |
| R1 | #40 Release checklist: store page, thumbnails, 2SV/Kids and Select, analytics, moderation | release | P1 | 0 | - |
| I2 | #41 Stop tracking the compiled .rbxl; publish builds as release artifacts | infra | P2 | 1 | I1 |

## Suggested agent assignment (up to 9 in parallel)

- **Lane 1 - Combat** (`track:combat`): C1, C2, C3, C4, C5, F0
- **Lane 2 - Match flow** (`track:match`): M1, M2, M3, M4, M5
- **Lane 3 - UI (HUD) / Lane 4 - UI (menus and input)** (`track:ui`): U1..U11
- **Lane 5 - Character / third-person** (`track:character`): T1, T2, T3, T4
- **Lane 6 - Audio** (`track:audio`): A1, A2, A3
- **Lane 7 - Progression** (`track:progression`): P1, P2, P3, P4, P5
- **Lane 8 - Infra / quality** (`track:infra`): I1, I2, I3, I4, I5
- **Lane 9 - Release (human)** (`track:release`): R1

## Start order (computed from hard dependencies)

1. **Wave 0 - start now, all independent (28 issues):** F0, I1, I3, I4, I5, C1, C5, M1, U1, U2, U3, U4, U5, U6, U7, U8, U9, U11, T3, T4, A1, A2, A3, P1, P5. R1 is human-owned.
2. **Wave 1 (after C1 / M1 / P1 / I1 merge):** C2, M2, P2, P3, P4, I2.
3. **Wave 2:** C3, C4, T1 (after C2); M3, M4, M5 (after M2).
4. **Wave 3:** T2 (after T1), U10 (after M5).
