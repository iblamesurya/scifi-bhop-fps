---
tags: [system, lobby, match]
---
# Lobby & Match Flow

## Files
| What | Path |
|---|---|
| Lobby map (Sky Island) | `assets/maps/AeroStrike_SkyIsland_Lobby.rbxmx` |
| Arena map (5v5) | `assets/maps/PhantomMidway_5v5_Map.rbxmx` |
| Lobby rebuild + interaction controller | `src/server/map/AeroStrike_Lobby_Rebuilder_And_Controller.server.luau` |
| Phantom Midway 5v5 V2 audit, spatial dedup & symmetrical cover | `src/server/map/PhantomMidway_V2_AuditFix.server.luau` |
| Phantom Midway client scaler, pooled impacts & car alarms | `src/client/graphics/PhantomMidway_ClientController.luau` |
| Arena / lobby spawn generation | `src/server/map/ArenaGenerator.luau` |
| Deploy, respawn, loadouts, speed records | `src/server/match/MatchService.luau` |
| Lobby / loadout overlay UI | `src/client/ui/LobbyApp.luau` |
| Map constants (pads, strafe walls, tunnels, decks) | `src/shared/configs/MapConfig.luau` |

## Lobby islands (children of `AeroStrike_SkyIsland_Lobby`)
01 Central Command · 02 Deployment/Matchmaking · 03 Armory & Crate · 04 Live-Fire Range & Killhouse · 05 Hall of Legends VIP · 06 Sky Parkour & Airspace

## Flow
1. Player joins → `MatchService` spawns at `ArenaGenerator.GetLobbySpawn()`.
2. `LobbyApp` (`SciFiLobbyGui`) shows weapon select + competitive-mode toggle + speed records.
3. **DEPLOY TO ARENA** → `ReplicatedStorage.RequestDeploy:FireServer(weaponId)`.
4. `MatchService.onRequestDeploy` validates weapon id, applies loadout, teleports to an arena spawn.
5. `"RETURN_TO_LOBBY"` payload (the *SKY ISLAND LOBBY* button) teleports back.
6. Respawn delay 3.0 s; arena cap `OPTIMAL_5V5_MAX_PLAYERS` = 10 (2 reserved friend slots). Default weapon `M4A1_Carbine`.

Related: [[Economy]], [[Architecture]]
