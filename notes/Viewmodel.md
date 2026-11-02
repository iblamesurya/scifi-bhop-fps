---
tags: [system, viewmodel, ui]
---
# Viewmodel, HUD & Graphics
Code: `src/client/viewmodel/{ViewmodelController,AnimatorBridge}.luau`, `src/shared/math/Spring.luau`, `src/client/ui/{HudApp,CrosshairModule}.luau`, `src/client/graphics/`.

## Viewmodel
- Bound with `BindToRenderStep` at `Camera.Value + 1` (no 1-frame lag).
- Springs (8× substepped): **sway** (mouse delta), **recoil** (per-shot kick from `WeaponData`), **movement** (landing impulse from `MovementController.OnLandedCallbacks`).
- ADS: computed from `AimPart` (`aimPart.CFrame:ToObjectSpace(vm.PrimaryPart.CFrame)`), never hardcoded; lerp by `adsAlpha`.
- Roll tilt: ±4.5° on A/D strafe, −8° while sliding.

## Rig convention (`vm_[weapon_id]`)
`RootPart` (invisible, PrimaryPart) · `LeftArm`/`RightArm` · `WeaponMesh` → `AimPart`, `MuzzleAttachment` (-Z), `ShellEjectAttachment`. All Motor6D-rigged to `RootPart`.

## HUD
Glassmorphic panel `RGB(10,14,20)`, transparency 0.35, 1px stroke, live STUDS/S. Cyan `#00F0FF` ≤ 45, orange `#FF6E00` above. FOV 85 → 103 with speed.

Related: [[Movement]], [[Architecture]]
