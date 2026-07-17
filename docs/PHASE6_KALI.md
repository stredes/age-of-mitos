# PHASE 6 - PERFORMANCE & POLISH (KALI)

## Tasks

### Performance
1. Optimize `scripts/pool/object_pool.gd` — implement dynamic pool sizing
2. Profile `scripts/core/pathfinder.gd` — cache paths, reduce A* calls
3. Optimize `scripts/combat/combat_manager.gd` — spatial hashing for projectiles
4. Optimize `scripts/ai/ai_director.gd` — throttle updates based on distance

### Gameplay Features
5. Add `scripts/units/formation_system.gd` — formation movement (line, wedge, circle)
6. Add `scripts/ui/hotkey_manager.gd` — keyboard shortcuts for all commands
7. Add `scripts/economy/market_system.gd` — resource trading between players
8. Add `scripts/world/animal_spawner.gd` — ambient animals (deer, wolves, birds)

### Bug Fixes
9. Fix pathfinding around building edges
10. Fix selection box not clearing after drag
11. Fix production queue display not updating
12. Fix AI not retreating when outmatched

### Testing
13. Add tests for formation system
14. Add tests for market system
15. Add tests for animal spawner
16. Run all tests and fix failures

## Git Workflow
```bash
cd ~/Workspace/age-of-mitos
git pull origin main
git checkout -b phase6-kali
# Make changes
git add -A
git commit -m "feat: performance, formations, market, animals"
git push origin phase6-kali
```
