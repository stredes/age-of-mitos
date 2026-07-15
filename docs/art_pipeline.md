# Age of Mitos Art Pipeline

This pipeline keeps all future visual assets consistent instead of generating isolated sprites one by one.

## Goals

- Keep one coherent pixel-art style across units, buildings, resources, environment, VFX, and UI.
- Produce assets that are immediately usable in Godot 4.4.1.
- Preserve the current procedural fallback system until real art covers a category.
- Avoid copyrighted references and copied sprites.

## Folder Layout

```text
assets/
  sprites/
    units/
      layered/
      sheets/
      portraits/
    buildings/
    resources/
    environment/
    decorative/
    ui/
  tiles/
    terrain/
    water/
```

Use lowercase snake_case file names:

```text
unit_villager_idle.png
unit_villager_layers.png
building_town_center.png
resource_olive_tree_stage_01.png
ui_icon_wood.png
```

## Production Flow

1. Pick an entry from `data/asset_manifest.json`.
2. Copy `docs/asset_prompt_master.md`.
3. Append the exact asset description from the manifest entry.
4. Generate 2-4 candidates with the same model/settings.
5. Select one candidate and clean it if needed.
6. Save to the manifest path.
7. Verify:
   - transparent background
   - no text/watermark
   - pixel sharpness
   - correct perspective
   - readable at RTS zoom
   - palette matches existing approved assets
8. Import in Godot with nearest filtering.
9. Replace procedural fallback only when the full category has enough coverage.

## Style Lock

Do not change these between batches:

- camera: top-down 45 degree RTS
- light: upper-left, soft
- palette: ancient Mediterranean, warm stone, bronze, iron, olive greens, deep blues
- outline: minimal
- canvas: transparent PNG with padding
- density: 32x32 terrain/resources, 48x48 small units, 64x64 buildings or hero units

## Layered Unit Rule

For units, prefer layered source files before animation sheets. The runtime animation system can animate body parts procedurally.

Required layers:

- head
- body
- left_arm
- right_arm
- left_leg
- right_leg
- weapon
- shield
- helmet
- hair
- cape, when relevant

## Godot Integration Notes

- Keep procedural visuals in `ProceduralSpriteFactory` as fallback.
- Add real PNG art category by category, not asset by asset.
- When replacing procedural units, load complete sets through one mapping table.
- Keep Android performance first: avoid oversized textures and excessive animation frames.

## First Milestone

The first consistent asset batch should cover the core readable loop:

- villager layered source
- spearman layered source
- archer layered source
- town center
- house
- barracks
- tree
- stone
- gold ore
- berry bush
- wood/food/stone/gold UI icons
