# Repository guidance

## Runtime and verification
- Target **WoW 3.3.5 private-server clients**, TOC interface `30300`, and **Lua 5.1**; this is not the Retail/Classic Wrath addon. Do not introduce newer Lua syntax or assume modern WoW APIs exist; compatibility helpers are bundled in `Skada/Libs/LibCompat-1.0/`.
- Run lint from the repository root: `luacheck . -q`; focused check: `luacheck Skada/Modules/Damage.lua -q` (substitute the changed file). CI uses `.luarocks/bin/luacheck . -q`, provisioning Lua `5.1.5`, LuaRocks `2.4.2`, Luacheck and Lanes; see `.github/workflows/lint.yml`.
- `.luacheckrc` supplies the WoW globals and `lua51c` standard and excludes bundled `Libs` files. A clean lint run does not verify library changes or runtime behavior.
- Focused threat regressions: `luajit tests/threat.lua` from the root (or use Lua 5.1); the harness mocks WoW APIs and is not wired into CI. See `tests/README.md` for in-game checks.
- There is no repository build. Runtime verification requires the game: install `Skada/` directly under `Interface/AddOns/`, not the repository wrapper folder. Install optional addon folders alongside it and explicitly enable them (both default to disabled).

## Loading and extension points
- `Skada/Skada.toc` loads libraries → locales → core → modules through each directory's `Load.xml`. Files are not auto-discovered: add new Lua files to the appropriate loader and preserve dependency order. Loader paths use WoW-style backslashes.
- `Skada/Core/Init.lua` populates the addon namespace; `Core.lua` turns that same table into the AceAddon and exports it globally. Main-addon files receive it through `local _, Skada = ...`; the separate optional addons use `_G.Skada` instead (their `...` namespace is not Skada's).
- Modules are registered with `Skada:RegisterModule(...)` and instantiated later by `LoadModules()` during initialization/enabling, subject to profile settings and dependencies. Follow `Skada/Modules/Damage.lua` for the `NewModule`, `RegisterForCL`, and `AddMode` pattern; registration/loading logic is in `Skada/Core/Functions.lua`, combat-log dispatch and segment lifecycle in `Skada/Core/Core.lua`.
- Spell/event/creature exclusion data shared by modes lives in `Skada/Core/Tables.lua`; do not duplicate those lists in individual modules. Actor/segment/window methods live in `Skada/Core/Prototypes.lua`, separate from display backends in `Skada/Core/Display/`.
- `SkadaDB` holds AceDB configuration; `SkadaCharDB` normally holds per-character segments. `SkadaStorage/` overrides `SetupStorage` and `CheckMemory` on `ADDON_LOADED`, redirecting segments to `SkadaStorageDB`. `SkadaImprovement/` registers boss-performance tracking and persists to `SkadaImprovementDB`; both depend on Skada.

## Editing quirks
- Add new localization keys to `Skada/Locales/enUS.lua` (the AceLocale default; `true` means use the key itself). `esMX.lua` serves both `esES` and `esMX`; there is no separate Spanish-Spain file. Improvement's additional strings live in `SkadaImprovement/Locales.lua`.
- Follow `.editorconfig`: Lua/XML/TOC use tabs (width 4), LF and a final newline. Bundled libraries have separate whitespace rules; avoid mass-formatting them.
- Read version/date metadata from `Skada/Skada.toc`, not the README heading, which is behind the manifest.
