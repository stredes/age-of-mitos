# PHASE 6 - PERFORMANCE & POLISH (MINT)

## Tasks

### Performance
1. Optimize `scripts/ui/minimap.gd` — reduce draw calls, use Image instead of draw
2. Optimize `scripts/animation/procedural_sprite_factory.gd` — cache generated frames
3. Optimize `scripts/world/chunk_loader.gd` — async loading, LOD system
4. Optimize `scripts/core/fog_of_war.gd` — use Image texture updates

### UI Improvements
5. Add `scripts/ui/victory_screen.gd` — win/lose conditions display
6. Add `scripts/ui/tech_tree_panel.gd` — visual technology tree
7. Add `scripts/ui/diplomacy_panel.gd` — ally/enemy management
8. Improve `scripts/ui/hud.gd` — add population cap display, age indicator

### World Polish
9. Add `scripts/world/day_night_cycle.gd` — dynamic lighting changes
10. Add `scripts/world/ambient_sounds.gd` — contextual audio (birds, wind, water)
11. Improve `scripts/world/resource_node.gd` — depletion animation, respawn
12. Improve `scripts/world/weather_system.gd` — weather affects gameplay (rain slows, fog reduces sight)

### Bug Fixes
13. Fix minimap click not moving camera
14. Fix selection panel not showing building info
15. Fix tooltips appearing behind other UI
16. Fix camera zoom limits not working

### Testing
17. Add tests for victory screen
18. Add tests for tech tree panel
19. Add tests for day/night cycle
20. Run all tests and fix failures

## Git Workflow
```bash
cd ~/Workspace/age-of-mitos
git pull origin main
git checkout -b phase6-mint
# Make changes
git add -A
git commit -m "feat: performance, UI panels, world polish"
git push origin phase6-mint
```
