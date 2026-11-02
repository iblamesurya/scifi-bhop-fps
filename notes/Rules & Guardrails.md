---
tags: [rules]
---
# Rules & Guardrails (from [[AGENTS]])

1. Every `.luau` file starts with `--!strict`; fully typed signatures.
2. **Banned**
   - `Tool` / `Backpack` for weapons
   - Humanoid default state machine (`EvaluateStateMachine` stays `false`)
   - `wait()`, `spawn()`, `delay()` → use `task.*`
   - `Instance.new()` in RenderStepped / firing loops → use pools (`TracerPool`)
   - Tables/strings over RemoteEvents for high-frequency packets → use `buffer`
3. **Pillar separation**
   - No hardcoded `rbxassetid://`, raw lighting values, or folder traversal in `src/`
   - Assets via `AssetRegistry`; animations via the animation registry; lighting via `LightingProfile`

> [!NOTE]
> All `.luau` files under `src/`, `animations/`, `graphics/` currently start with `--!strict` (checked 2026-11-02). `Instance.new` use outside pools (e.g. one-time setup in `CharacterService`) is worth auditing — see [[Task Log]].

See also [[Architecture]].
