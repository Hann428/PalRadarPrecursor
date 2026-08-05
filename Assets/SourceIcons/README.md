PalRadarPrecursor source icons

These PNG files are copied from FModel exports and are intended as the import source
for the packaged PalRadarPrecursor content mod. The game should not depend on
`D:\PalOutput` or loose PNG files at runtime.

Source export root:
`D:\PalOutput\Exports\Pal\Content\Pal\Texture`

Manifest:
`source_icon_manifest.json`

Directory usage:
- `StaticMap/Compass`: compact map-style icons for the M-key map overlay.
- `StaticMap/BuildObject`: descriptive build/object icons for filters, details, and fallback marker styles.
- `DynamicRadar/Elements`: element icons for later dynamic markers and radar labels.
- `DynamicRadar/Markers`: rare/strong/dungeon marker support icons.
- `PalRelicStatues`: Pal portrait icons for the new collectible statue/relic types.

Packaging plan:
1. Import these PNGs into the Unreal mod content project.
2. Cook them into the PalRadarPrecursor content package.
3. Use stable cooked asset paths such as `/Game/PalRadarPrecursor/UI/Icons/...`.
4. Point the Lua overlay icon mapping at those packaged `Texture2D` assets.
