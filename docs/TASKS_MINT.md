# TASK LIST FOR MINT (PC 3) — Age of Mitos

## Your Role: UI/UX + World Systems + Performance
Focus on: UI, HUD, menus, world generation, animations, and performance optimization.

## Tasks (in order)

### PHASE 1: Analysis & Testing
1. Read ALL scripts in `scripts/ui/` — document UI flow, find issues
2. Read ALL scripts in `scripts/animation/` — verify animations work
3. Read ALL scripts in `scripts/world/` — verify world generation
4. Read `scripts/core/` — verify camera, grid, pathfinder, fog
5. Create test files in `tests/` for each system:
   - `tests/test_hud.gd`
   - `tests/test_build_menu.gd`
   - `tests/test_train_menu.gd`
   - `tests/test_selection_panel.gd`
   - `tests/test_minimap.gd`
   - `tests/test_camera_controller.gd`
   - `tests/test_grid_manager.gd`
   - `tests/test_pathfinder.gd`

### PHASE 2: UI/UX Bug Fixes
6. Fix any UI layout issues
7. Fix any menu navigation bugs
8. Fix tooltip/label display issues
9. Fix minimap rendering
10. Fix selection panel display

### PHASE 3: UI Improvements
11. Improve `hud.gd` — add resource icons, better layout
12. Improve `build_menu.gd` — add building previews, descriptions
13. Improve `train_menu.gd` — add unit previews, queue display
14. Improve `selection_panel.gd` — better unit/building info
15. Improve `minimap.gd` — click to move, better colors
16. Add `scripts/ui/tooltip_system.gd` — hover tooltips for all buttons

### PHASE 4: World System Improvements
17. Improve `world_generator.gd` — better terrain variety
18. Improve `resource_node.gd` — better resource placement
19. Improve `fog_of_war.gd` — smoother reveal/hide
20. Improve `weather_system.gd` — better weather effects

### PHASE 5: Animation Improvements
21. Improve `unit_animation_controller.gd` — smoother transitions
22. Improve `building_animation_controller.gd` — construction stages
23. Improve `decorative_world_animations.gd` — more ambient life
24. Improve `particle_effects.gd` — better combat/destruction effects

### PHASE 6: Performance Optimization
25. Optimize `object_pool.gd` — better pooling strategies
26. Optimize `chunk_loader.gd` — smarter chunk loading
27. Profile and optimize hot paths
28. Reduce per-frame allocations

## Git Branch
```bash
cd ~/Workspace/age-of-mitos
git checkout -b improvements-mint
# Make changes
git add -A
git commit -m "feat: UI/UX, world, animation improvements and tests"
git push origin improvements-mint
```

## Verification
After each phase, run:
```bash
# Check for syntax errors
find . -name "*.gd" -exec grep -l "extends\|class_name" {} \; | head -20
# Verify scenes load
find . -name "*.tscn" -exec echo "Scene: {}" \;
```

## Status Updates
Update `docs/MINT_STATUS.md` after each phase with:
- What was completed
- What bugs were found/fixed
- What improvements were made
- Any blockers or issues
