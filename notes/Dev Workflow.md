---
tags: [workflow]
---
# Dev Workflow
```bash
rokit install                       # Rojo, Wally, StyLua, Selene
wally install                       # packages → /Packages
rojo serve default.project.json     # live-sync to Studio
selene src/                         # lint
stylua --check src/                 # format check
```
- `.gitignore` excludes `*.rbxl`, `Packages/`, `.rojo/`, `.obsidian/`, `*.base` — this vault's settings stay local.
- Rojo only maps the folders in `default.project.json`; `notes/` is not synced to Studio.
- Config files: `rokit.toml`, `wally.toml`, `selene.toml`, `stylua.toml`, `asphalt.toml`.

Related: [[Architecture]], [[Rules & Guardrails]]
