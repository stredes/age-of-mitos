# Age of Mitos — Context File

## Project Overview
Real-time strategy game inspired by ancient civilizations. Built with Godot 4.4.1 (project config says 4.2, templates are 4.4.1). Renderer: `gl_compatibility`. Export target: Android (also works on desktop).

**Package:** `com.ageofmitos.game` | **Version:** 0.1.1 (code 2) | **Viewport:** 1280x720

## Current Playable Loop
- Left click/tap uses `SelectionManager` to select local units/buildings; drag selection selects local units in a rectangle.
- Selected units show their selection ring via `UnitBase.is_selected` and `SelectionComponent`.
- Right click sends selected units to move using a basic square formation target layout; right clicking a harvestable `ResourceNode` sends villagers into `HarvestState`.
- A key enters attack-move mode: right-click sends units to move toward a point, attacking any enemies encountered along the way.
- Build menu placement creates real `BuildingManager` buildings, spends resources, marks the grid, and starts progressive construction.
- Buildings under construction advance over build time, show a progress bar/ring, emit construction particles, update construction animation frames, and play completion feedback before becoming active.
- Selected buildings show a pulsing selection ring and construction progress if unfinished.
- Building production now advances every frame, uses unit `train_time`, spends unit costs from `SelectionPanel`, and spawns completed units near the source building.
- Command buttons now route through `GameWorld`: Stop halts selected units, Build opens the build menu, gather buttons assign selected villagers, and `train_*` commands queue units from the selected building with central cost handling.
- Command panel buttons show hotkeys/tooltips and pressed feedback; keyboard hotkeys include A attack-move, B build, S stop, H hold position, W/F/T/G gather resources, and V/Z/P/R/C for common unit training.
- MovementComponent has acceleration, deceleration, turn smoothing, terrain speed, obstacle slowdown, and walking dust.
- Camera supports smooth zoom, inertia, edge scrolling, arrow-key panning, screen shake, touch circle feedback on tap, green arrow move-order feedback, and Space to re-center on army. WASD is reserved for command hotkeys, not camera movement.
- Audio buses Music/SFX/Ambience are created at runtime if missing, so validation/export no longer emits audio bus warnings.
- Pathfinder uses `AStarGrid2D.region` for Godot 4.4 instead of deprecated `size`.
- Latest exported debug APK: `build/age_of_mitos_v0.1.1.apk`, copied to `C:\Users\bodega 1\Desktop\age_of_mitos_v0.1.1.apk` on 2026-07-15.

## RTS AAA Overhaul Direction
The UX target is a polished classic RTS feel inspired by Age of Empires II: Definitive Edition usability while preserving Age of Mitos identity.

Priorities:
- Immediate input feedback for selection, move, harvest, build, train, attack, damage, completion, and errors.
- Progressive construction with foundations, work particles, staged visuals, completion burst, camera shake, and active-state transition.
- Bottom contextual command panel, resource bar, minimap, selection info, queues, tooltips, hotkeys, and disabled-state reasons.
- Smooth unit motion with acceleration/deceleration, turn anticipation, local avoidance, and formations.
- Distinct resource loops: walk, harvest animation, particles, visible carried resource, drop-off, and automatic return.
- Android performance: pooling, chunk/visibility culling, reusable animations, and no unnecessary per-frame allocations.

## Living World Direction
Age of Mitos should feel like a classical RTS with a living, organic world inspired by WorldBox-style ambience, without becoming a clone.

Core principles:
- Keep RTS identity first: economy, construction, combat, scouting, AI.
- Make the world feel alive through procedural animation, particles, ambient simulation, and autonomous behavior.
- Avoid static objects. Units, resources, buildings, water, clouds, animals, and foliage should have subtle motion.
- Prefer procedural/math-driven animation over large sprite-frame sets.
- Maintain readable pixel-art silhouettes, natural colors, minimal outlines, and Android-friendly performance.

Current living-world systems:
- `scripts/animation/procedural_sprite_factory.gd` generates unit/building `SpriteFrames` at runtime.
- `UnitAnimationController` supports idle, walk/run, attack, harvest/mine variants, build, carry, hurt, death, celebrate, sleep, fear, and victory.
- `BuildingAnimationController` supports construction, active, producing, damaged, burning, destroyed, smoke/fire, flags, and mill hooks.
- `DecorativeWorldAnimations` is attached by `game_world.gd` and drives clouds, birds, animals, day/night tint, tree/grass/water ambience.
- `WeatherSystem` is attached by `game_world.gd` and cycles clear, rain, fog, storm, and strong wind with camera-following visuals.
- `ParticleEffectsManager` is pooled and handles walking dust, harvesting, mining, combat, destruction, fire/smoke, water, healing, and level-up effects.
- `ResourceNode` draws procedural trees, stone, food bushes, and gold with subtle motion.

Performance rules:
- Target 60 FPS on Android.
- Throttle distant decorative updates.
- Use pooled particles; do not instantiate repeated one-shot effects directly.
- Avoid per-frame allocations in high-count world objects.
- Expand ambience modularly through existing systems before adding new global managers.

## Art Production Pipeline
Do not generate or add sprites one by one without a shared style plan. Use the repo pipeline so every asset belongs to the same visual universe.

Source files:
- `docs/asset_prompt_master.md` — fixed master prompt for image generation tools.
- `docs/art_pipeline.md` — production flow, naming rules, review checklist, and Godot integration notes.
- `data/asset_manifest.json` — prioritized asset batches, descriptions, target canvas sizes, and destination paths.

Rules:
- Add or update a manifest entry before creating new PNG art.
- Generate assets in batches by category: core units, core buildings, resources, UI icons, etc.
- Use lowercase snake_case filenames matching the manifest path.
- Keep transparent PNG output, top-down 45 degree RTS perspective, upper-left soft lighting, and ancient Mediterranean palette.
- Runtime procedural sprites stay as fallback until a full category has consistent coverage.
- Never use copyrighted assets or copied sprites.

## Quick Commands

### Export APK
```bash
$env:ANDROID_HOME = "C:\android-sdk"; $env:JAVA_HOME = "C:\jdk-17"
& "tools\Godot_v4.4.1-stable_win64.exe" --headless --export-debug "Android Debug" "build/age_of_mitos_v0.1.1.apk"
```
Output: `build/age_of_mitos_v0.1.1.apk`

### Copy APK to Desktop
```powershell
Copy-Item "build\age_of_mitos_v0.1.1.apk" "C:\Users\bodega 1\Desktop\age_of_mitos_v0.1.1.apk" -Force
```

## Tools & Paths
- **Godot:** `tools/Godot_v4.4.1-stable_win64.exe`
- **Android SDK:** `C:\android-sdk` (build-tools 34, platform android-34)
- **Java:** `C:\jdk-17`
- **Debug Keystore:** `C:\Users\bodega 1\AppData\Roaming\Godot\keystores\debug.keystore` (pass: `android`)
- **Export Templates:** `C:\Users\bodega 1\AppData\Roaming\Godot\export_templates\4.4.1.stable\`

## Export Config Notes
- Export preset: `export_presets.cfg` → "Android Debug"
- `gradle_build/use_gradle_build=false` (standard APK export, NOT Gradle)
- If you add `min_sdk` or `target_sdk` fields, you MUST enable Gradle build, otherwise export fails with: *"Min SDK solo puede sobrescribirse cuando está activada la opción Usar Gradle Build"*
- Architectures: armeabi-v7a + arm64-v8a
- Package is signed with debug keystore

## Architecture

### Autoloads (Global Singletons)
| Name | Script | Role |
|------|--------|------|
| EventBus | `autoload/event_bus.gd` | Signal bus connecting all systems |
| GameManager | `autoload/game_manager.gd` | Game state, players, start/stop |
| DataManager | `autoload/data_manager.gd` | Loads JSON data files |
| AudioManager | `autoload/audio_manager.gd` | Sound effects |

### Scene Flow
```
main_menu.tscn → (New Game button) → game_world.tscn
```

### Core Systems (`scripts/core/`)
| Script | Class | Base | Role |
|--------|-------|------|------|
| `camera_controller.gd` | CameraController | Camera2D | RTS pan/zoom |
| `input_manager.gd` | InputManager | Node | Mouse/keyboard routing |
| `grid_manager.gd` | GridManager | Node | Tile-based world, `is_buildable()`, `place_building()` |
| `pathfinder.gd` | Pathfinder | Node | AStarGrid2D pathfinding |
| `fog_of_war.gd` | FogOfWar | Node2D | Visibility system |

### Unit System (`scripts/units/`)
| Script | Class | Base |
|--------|-------|------|
| `unit_base.gd` | UnitBase | CharacterBody2D |
| `unit_state_machine.gd` | UnitStateMachine | Node |
| `unit_manager.gd` | UnitManager | Node |

**Components:** `health_component.gd`, `movement_component.gd`, `selection_component.gd`, `combat_component.gd`, `harvest_component.gd`

**States (all extend UnitState):** Idle, Move, Attack, AttackMove, Patrol, HoldPosition, Build, Harvest, Dead, Celebrate, Hurt

**Note:** `UnitManager` uses `scenes/units/unit.tscn`; fallback creation is still available for safety.

**Visual hierarchy note:** In `unit.tscn`, `AnimatedSprite2D` is a sibling of `UnitAnimationController`, not a child of the controller. Animation controllers must search from the parent entity first, then fallback to their own subtree.

### Building System (`scripts/buildings/`)
| Script | Class | Base |
|--------|-------|------|
| `building_base.gd` | BuildingBase | StaticBody2D |
| `building_manager.gd` | BuildingManager | Node |
| `construction_system.gd` | ConstructionSystem | Node |
| `production_queue.gd` | ProductionQueue | Node |

**Note:** `BuildingManager` uses `scenes/buildings/building.tscn`; fallback creation is still available for safety.

**Visual hierarchy note:** In `building.tscn`, `AnimatedSprite2D` is a sibling of `BuildingAnimationController`, not a child of the controller. `BuildingAnimationController` must find the sprite from the parent building. `BuildingBase` also has a procedural frame fallback if the controller cannot assign frames.

### Other Systems
- `scripts/combat/` — CombatManager, DamageCalculator, Projectile
- `scripts/ai/` — AIDirector, AIBuilder, AIEconomy, AIMilitary
- `scripts/world/` — WorldGenerator, WorldData, ChunkLoader, ResourceNode, WeatherSystem
- `scripts/selection/` — SelectionManager
- `scripts/economy/` — ResourceManager
- `scripts/technology/` — TechnologyTree
- `scripts/save/` — SaveManager
- `scripts/pool/` — ObjectPool
- `scripts/animation/` — ProceduralSpriteFactory, BuildingAnimationController, UnitAnimationController, DecorativeWorldAnimations, ParticleEffects
- `scripts/ui/` — UIManager, HUD, Minimap, BuildMenu, TrainMenu, SelectionPanel

### Data-Driven Design
All game data stored in JSON under `data/`:
- `buildings.json` — building definitions (NOTE: `size` field is `{"x":3,"y":3}` Dictionary, NOT Vector2i)
- `units.json` — unit definitions
- `resources.json` — resource types
- `technologies.json` — tech tree
- `civilizations.json` — civilization definitions
- `asset_manifest.json` — prioritized art-production batches and target paths

**Critical:** JSON `size` fields are Dictionaries (`{"x":N,"y":N}`). Code must explicitly convert to `Vector2i`:
```gdscript
var raw_size = building_data.get("size", {"x": 1, "y": 1})
var size = Vector2i(raw_size.get("x", 1), raw_size.get("y", 1))
```

### Input Actions
| Action | Binding |
|--------|---------|
| `select` | Left mouse button |
| `action` | Left mouse button |
| `pan` | Right mouse button |
| `zoom_in` | Mouse wheel up |
| `zoom_out` | Mouse wheel down |
| `build` | B key |
| `cancel` | Escape |
| `recenter_army` | Space |
| `attack_move` | A key (then right-click target) |
| `hold_position` | H key (unit stays in place and defends itself) |

## Known Bugs (Fixed in v0.1.1)
1. **Signal timing:** `GameManager.start_game()` was called from menu BEFORE scene change → `EventBus.game_started` emitted with zero listeners → ResourceManager never initialized. Fix: removed early call, let `_initialize_world()` handle it.
2. **Building size type mismatch:** JSON `{"x":3,"y":3}` is Dictionary, code expected Vector2i. Fixed with explicit conversion.
3. **Fog world rect stale:** `_world_rect` set in `_ready()` with default 128x128, never updated when map size differs. Fixed by recalculating in `_initialize_fog_image()`.
4. **Missing scene references:** `UnitManager` and `BuildingManager` now use existing `unit.tscn` and `building.tscn`; procedural fallback remains available.
5. **Chunk camera coordinates:** `ChunkLoader` now converts camera pixel position to chunk coordinates correctly.
6. **Godot 4.4 API cleanup:** fog no longer uses `Image.lock()/unlock()`, and pooled particles use safe property assignment for current `CPUParticles2D`.
7. **Missing export icon:** `icon.svg` exists, so Android export no longer reports missing `res://icon.svg`.
8. **Invisible buildings:** animation controllers originally searched only inside themselves for `AnimatedSprite2D`, but the scenes place sprites as sibling nodes. Fixed by searching from the parent unit/building first and adding a `BuildingBase` procedural visual fallback.

## Current Asset / Docs State
- `assets/sprites/` contains pipeline folders for `units/layered`, `units/sheets`, `units/portraits`, `buildings`, `resources`, `environment`, `decorative`, and `ui`.
- `assets/tiles/` contains `terrain/` and `water/` pipeline folders.
- `docs/asset_prompt_master.md` contains the fixed master prompt for consistent AI-generated pixel art.
- `docs/art_pipeline.md` documents production flow, naming rules, review checklist, and Godot import notes.
- `data/asset_manifest.json` tracks prioritized generated-asset batches and target paths.
- Runtime art remains procedural until a full category has consistent PNG coverage.
- Still-empty placeholders: `assets/animations`, `assets/audio`, `assets/fonts`, `assets/music`, `scenes/ui`, `scripts/data`, `scripts/effects`, `scripts/navigation`, `tests`.

## Project Structure
```
age_of_mitos/
├── project.godot              # Engine config
├── export_presets.cfg         # Android export settings
├── AGENTS.md                  # This file
├── autoload/                  # 4 global singletons
│   ├── audio_manager.gd
│   ├── data_manager.gd
│   ├── event_bus.gd
│   └── game_manager.gd
├── data/                      # gameplay JSON + asset_manifest.json
├── docs/                      # asset pipeline docs
├── assets/                    # art/audio pipeline folders + generated PNG destinations
├── scenes/                    # 6 scenes
│   ├── buildings/building.tscn
│   ├── effects/projectile.tscn
│   ├── main/game_world.tscn + .gd
│   ├── main/main_menu.tscn + .gd
│   ├── main/menu_ui_builder.gd
│   ├── units/unit.tscn
│   └── world/resource_node.tscn
├── scripts/                   # gameplay and presentation GDScript files
│   ├── ai/ (4)
│   ├── animation/ (5)
│   ├── buildings/ (4)
│   ├── combat/ (3)
│   ├── core/ (5)
│   ├── economy/ (1)
│   ├── pool/ (1)
│   ├── save/ (1)
│   ├── selection/ (1)
│   ├── technology/ (1)
│   ├── ui/ (6)
│   ├── units/ (3 + 5 components + 9 states)
│   └── world/ (5)
├── build/                     # Exported APK
├── tools/                     # Godot exe + Android SDK
└── .godot/                    # Engine cache (~12727 imported assets)
```
