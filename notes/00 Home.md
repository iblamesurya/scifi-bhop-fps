---
tags: [moc, home]
---
# Sci-Fi Bhop FPS — Project Vault

Roblox FPS in strict Luau: Quake-style bunny-hopping, procedural viewmodels, lag-compensated hitscan, glassmorphic HUD. Built with Rojo 7, Rokit, Wally.

## Map of Content
- [[Architecture]] — the 4 pillars and Rojo mapping
- [[Rules & Guardrails]] — hard rules for every contributor/AI agent
- [[Movement]] — bhop, air-strafe, slide
- [[Combat & Networking]] — shot packet, server validation, hitbox rewind
- [[Viewmodel]] — springs, ADS, render priority
- [[Lobby & Match Flow]] — Sky Island lobby, deploy, arena, respawn
- [[Economy]] — buy phase, credits, armor, DataStore
- [[Dev Workflow]] — CLI commands, Rojo, lint
- [[Task Log]] — TODOs and decisions

## Source documents (in repo root)
- [[AGENTS]] — canonical architecture + agent rules
- [[README]]

## Quick links to code
- `src/client/init.client.luau`, `src/server/init.server.luau` — bootstrappers
- `src/shared/configs/` — WeaponData, MovementConfig, AssetRegistry, MapConfig, EconomyConfig
- `assets/maps/` — `AeroStrike_SkyIsland_Lobby.rbxmx`, `PhantomMidway_5v5_Map.rbxmx`
