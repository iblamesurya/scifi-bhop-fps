# SCI-FI BHOP FPS — Architecture & AI Agent Context Guide

A production-grade, high-speed multiplayer First-Person Shooter (FPS) built on Roblox using `--!strict` Luau, Rojo 7, Rokit, and Wally. The core gameplay loop combines **Quake/Source-style bunny-hopping and air-strafing**, **procedural 3D spring viewmodels**, **client-predicted hitscan with 60Hz server-side hitbox rewind**, and a **minimalist glassmorphic sci-fi HUD**.

---

## 1. AI Coding Agent Rules & Guardrails (CRITICAL)

Every AI coding agent or contributor working in this repository MUST obey these rules:

1. **Strict Typing Mandatory:** Every `.luau` file MUST begin with `--!strict` on line 1. All function signatures, tables, and return types must be explicitly typed.
2. **BANNED Legacy Roblox APIs:**
   - NEVER use Roblox `Tool` instances or `Backpack` for weapons.
   - NEVER use default `Humanoid` movement braking (`Humanoid.EvaluateStateMachine` MUST remain `false` during active gameplay).
   - NEVER use `wait()`, `spawn()`, or `delay()` (always use `task.wait()`, `task.spawn()`, `task.delay()`).
   - NEVER use `Instance.new()` inside `RenderStepped` or firing loops (always use pre-allocated ring-buffer object pools like `TracerPool.luau`).
   - NEVER send tables or strings over `RemoteEvents` for high-frequency combat/movement packets (always serialize into raw Luau `buffer` objects).
3. **Strict 4-Pillar Separation of Concerns:**
   - Gameplay scripts inside `src/` MUST NEVER contain hardcoded `rbxassetid://` strings, raw lighting values, or direct folder traversal.
   - All 3D models, audio, and sprites are queried exclusively through `src/shared/configs/AssetRegistry.luau`.
   - All animation IDs, priorities, and fade times are queried exclusively through `animations/registry/init.luau`.
   - All lighting, post-processing, and FOV presets live exclusively in `graphics/presets/LightingProfile.luau`.

---

## 2. Master Repository Architecture (The 4 Pillars)

The repository is split into four root domains mapped into Roblox Studio via `default.project.json`:

```text
scifi-bhop-fps/
├── rokit.toml                          # Toolchain: Rojo 7.4.4, Wally, StyLua, Selene
├── wally.toml                          # Dependencies: sleitnick/trove, sleitnick/signal
├── default.project.json                # Rojo DataModel synchronization tree
│
├── assets/                             # [PILLAR 1: 3D MODELS, AUDIO & UI SPRITES]
│   ├── models/
│   │   ├── viewmodels/                 # 1P rigs (.rbxm) -> ReplicatedStorage.Assets.Models.viewmodels
│   │   ├── worldmodels/                # 3P meshes (.rbxm) -> ReplicatedStorage.Assets.Models.worldmodels
│   │   └── characters/                 # Competitive R6 rig (.rbxm)
│   ├── audio/                          # Raw .ogg files (weapons, movement, UI)
│   └── ui_sprites/                     # Raw .png reticles and weapon icons
│
├── animations/                         # [PILLAR 2: ANIMATIONS & KEYFRAME REGISTRIES]
│   ├── blender_source/                 # Source .blend / .fbx files (ignored by Rojo)
│   ├── exported_rbxm/                  # KeyframeSequence backups (.rbxm)
│   └── registry/                       # Synced -> ReplicatedStorage.Animations
│       ├── init.luau                   # Master AnimationRegistry module
│       ├── ViewmodelAnims.luau         # 1P weapon idle, equip, reload, inspect tracks
│       └── CharacterAnims.luau         # 3P R6 slide, air-strafe tuck, locomotion tracks
│
├── graphics/                           # [PILLAR 3: LIGHTING, PBR MATERIALS & VFX PREFABS]
│   ├── vfx_prefabs/                    # Synced -> ReplicatedStorage.Graphics.VFX (.rbxm)
│   │   ├── PlasmaTracerBeam.rbxm       # Pooled beam tracer template
│   │   ├── MuzzleFlashSciFi.rbxm       # Muzzle particle prefab
│   │   └── ImpactSparks.rbxm           # Surface hit spark prefab
│   ├── materials/                      # Synced -> MaterialService.CustomMaterials (.rbxm)
│   └── presets/                        # Synced -> ReplicatedStorage.Graphics.Presets
│       ├── LightingProfile.luau        # Future lighting, Bloom, ColorCorrection, FOV warp
│       └── GraphicsQualityTiers.luau   # Competitive Low (240+ FPS) vs Ultra Sci-Fi presets
│
└── src/                                # [PILLAR 4: PURE LUAU GAMEPLAY LOGIC]
    ├── client/                         # Synced -> StarterPlayer.StarterPlayerScripts.Client
    │   ├── init.client.luau            # Client bootstrapper
    │   ├── movement/
    │   │   ├── MovementController.luau # Quake air-strafe, auto-bhop, and ground friction math
    │   │   └── SlideController.luau    # Slide impulse, low-friction decay, camera crouch offset
    │   ├── combat/
    │   │   ├── WeaponController.luau   # Input state machine, client raycast, 28B buffer sender
    │   │   └── TracerPool.luau         # 50-instance zero-GC ring buffer for PlasmaTracerBeam
    │   ├── viewmodel/
    │   │   ├── ViewmodelController.luau# RenderStepped camera bind, AimPart ADS lerp, 3D Springs
    │   │   └── AnimatorBridge.luau     # AnimationTrack loader for viewmodel Motor6Ds
    │   ├── graphics/
    │   │   ├── GraphicsController.luau # Applies LightingProfile + B-hop velocity FOV scaling
    │   │   └── VFXController.luau      # Muzzle flash & impact particle dispatcher
    │   └── ui/
    │       ├── HudApp.luau             # Minimalist sci-fi glassmorphic HUD & STUDS/S telemetry
    │       └── CrosshairModule.luau    # Velocity-reactive dynamic reticle
    │
    ├── server/                         # Synced -> ServerScriptService.Server
    │   ├── init.server.luau            # Server bootstrapper
    │   ├── combat/
    │   │   ├── HitboxHistory.luau      # 60Hz 1-second circular buffer of player part CFrames
    │   │   └── CombatValidator.luau    # Unpacks 28B shot buffer, rewinds hitboxes, applies damage
    │   └── replication/
    │       └── StanceReplicator.luau   # UnreliableRemoteEvent buffer sync for 3P look pitch/slide
    │
    └── shared/                         # Synced -> ReplicatedStorage.Shared
        ├── configs/
        │   ├── WeaponData.luau         # Read-only stats: RPM, damage, headshot mult, recoil kick
        │   ├── MovementConfig.luau     # Read-only physics constants: AirAccelerate, speed caps
        │   └── AssetRegistry.luau      # Single source of truth for Models, Audio, and Sprites
        ├── math/
        │   ├── Spring.luau             # 3D Hooke's Law damped harmonic oscillator (8x substepped)
        │   └── QuakeMath.luau          # Shared vector projection accelerate() & applyFriction()
        └── network/
            └── ShotPacket.luau         # 28-byte binary buffer serializer/deserializer
```

---

## 3. Core Systems Specifications

### 3.1 Custom Bunny-Hop & Air-Strafe Physics (`MovementController.luau`)
* **State Machine Bypass:** Sets `Humanoid.EvaluateStateMachine = false` every frame and drives `HumanoidRootPart.AssemblyLinearVelocity` directly.
* **Ground Detection:** Casts a downward ray of length `MovementConfig.GroundRayLength` (`3.4` studs) from `HumanoidRootPart.Position` excluding the local character.
* **Frame-Perfect Auto-Bhop:** Holding `Space` sets `jumpQueued = true`. If `IsGrounded` transitions to `true` while `jumpQueued == true`, vertical velocity is immediately set to `JumpVelocity` (`42` studs/s) and `IsGrounded` is forced `false` on the exact landing frame—completely bypassing `applyFriction()`.
* **Quake Air Acceleration:** Mid-air velocity projection uses `currentVel:Dot(wishDir)` capped against `MaxAirWishSpeed` (`6.5`) with `AirAccelerate` (`120`), allowing players to smoothly gain horizontal momentum up to `HardSpeedCap` (`85` studs/s) by turning the camera into their strafe key (`A`/`D`).
* **Slide-Hopping:** Pressing `LeftControl` or `C` above `MinSlideSpeed` (`26` studs/s) applies a forward `SlideBoostImpulse` (`16` studs/s) and drops ground friction from `6.0` to `1.2`.

### 3.2 First-Person Viewmodel & Procedural Springs (`ViewmodelController.luau`)
* **Render Priority:** Bound via `RunService:BindToRenderStep` at `Enum.RenderPriority.Camera.Value + 1` to eliminate 1-frame camera lag.
* **3D Harmonic Springs (`Spring.luau`):**
  - `swaySpring`: Tracks mouse delta (`UserInputService:GetMouseDelta()`) for rotational weapon lag.
  - `recoilSpring`: Receives 3D impulse kicks (`Pitch`, `Yaw`, `Roll/Pushback`) per shot from `WeaponData`.
  - `movementSpring`: Receives downward velocity impulses from `MovementController.OnLandedCallbacks` proportional to vertical landing speed.
* **Mathematical ADS Alignment:** Never uses hardcoded ADS CFrame offsets. Computes the relative offset dynamically using `local aimOffset = aimPart.CFrame:ToObjectSpace(activeViewmodel.PrimaryPart.CFrame)` and interpolates `baseCFrame:Lerp(Camera.CFrame * aimOffset, adsAlpha)`.
* **Air-Strafe Roll Tilt:** Smoothly tilts the weapon roll angle (`±4.5°` on `A`/`D` strafe, `-8°` during slides).

### 3.3 Binary Buffer Networking & Lag-Compensated Hit Registration
* **28-Byte Shot Packet Schema (`ShotPacket.luau`):**
  - `Offset 00..07` (`f64` - 8 bytes): Client firing timestamp from `workspace:GetServerTimeNow()`.
  - `Offset 08..19` (`f32 x 3` - 12 bytes): Ray origin vector (`Origin.X`, `Origin.Y`, `Origin.Z`).
  - `Offset 20..27` (`f32 x 2` - 8 bytes): Ray orientation angles (`Pitch`, `Yaw` in radians).
* **Server Validation Pipeline (`CombatValidator.luau`):**
  1. Verifies `typeof(packet) == "buffer"` and `buffer.len(packet) == 28`.
  2. Checks rate-of-fire interval against `(60 / stats.FireRateRPM) * 0.88`.
  3. Validates origin distance against `shooterHead.Position` (max `14` studs tolerance to account for `85` studs/s bunny-hop speed).
  4. Clamps target rewind time to `[serverNow - 0.45, serverNow]`.
  5. Temporarily rewinds all enemy character `BasePart` CFrames using the 60Hz snapshot ring buffer (`HitboxHistory.luau`), executes `workspace:Raycast()`, immediately restores current CFrames, and applies damage.

### 3.4 Sci-Fi Minimalist HUD & Graphics (`HudApp.luau` & `GraphicsController.luau`)
* **Telemetry Panel:** Glassmorphic dark slate container (`Color3.fromRGB(10, 14, 20)`, `BackgroundTransparency = 0.35`) with a `1px` `UIStroke` and live `STUDS/S` digital readout.
* **Overdrive Color Shift:** Telemetry bar and border glow Neon Cyan (`#00F0FF`) during standard movement (`<= 45` studs/s) and shift to Overdrive Neon Orange (`#FF6E00`) when chaining bunny-hops above `45` studs/s.
* **Velocity FOV Warp:** Camera `FieldOfView` scales smoothly from `85` (at base walk speed) up to `103` (at max bunny-hop speed).

---

## 4. 3D Asset & Rig Conventions

Every weapon model exported into `assets/models/viewmodels/` MUST adhere to this exact hierarchy:
* `vm_[weapon_id]` (`Model` with `PrimaryPart` set to `RootPart`)
  * `RootPart` (`Part`, `Anchored = false`, `CanCollide = false`, `Transparency = 1`)
  * `LeftArm` & `RightArm` (`MeshPart`, `CanCollide = false`, rigged to `RootPart` via `Motor6D`)
  * `WeaponMesh` (`MeshPart`, `CanCollide = false`, rigged to `RootPart` via `Motor6D`)
    * `AimPart` (`BasePart` or `Attachment` centered directly on the optic reticle axis)
    * `MuzzleAttachment` (`Attachment` positioned at the barrel tip, `-Z` facing forward)
    * `ShellEjectAttachment` (`Attachment` positioned at the ejection port)

---

## 5. Development Workflow & CLI Commands

```bash
# 1. Install toolchain binaries (Rojo, Wally, StyLua, Selene)
rokit install

# 2. Install Wally package dependencies into /Packages
wally install

# 3. Start Rojo live-sync server with Roblox Studio
rojo serve default.project.json

# 4. Run static analysis & formatting before committing
selene src/
stylua --check src/
```
