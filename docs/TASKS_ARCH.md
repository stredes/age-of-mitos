# TASK LIST FOR ARCH (PC 1) — Age of Mitos

## Your Role: Coordination + Data Balance + Integration
Focus on: Coordinating work, balancing game data, integrating changes, final testing.

## Tasks (in order)

### PHASE 1: Coordination Setup
1. Create `docs/MULTI_PC_TASKS.md` (already done)
2. Create `docs/BALANCE_CHANGES.md` — track all balance changes
3. Create `docs/BUG_FIXES.md` — track all bug fixes
4. Create `docs/IMPROVEMENTS.md` — track all improvements
5. Set up git branches for each PC's work

### PHASE 2: Data Balance Review
6. Review `data/units.json` — adjust for balance:
   - Villager gather rates should be balanced
   - Military unit costs should be reasonable
   - Unit HP/damage should be proportional
   - Training times should be realistic
7. Review `data/buildings.json` — adjust for balance:
   - Building costs should progress logically
   - Build times should be reasonable
   - Building HP should scale with importance
   - Production capacity should be balanced
8. Review `data/technologies.json` — verify:
   - Tech tree has no dead ends
   - Prerequisites make sense
   - Bonuses are balanced
   - Costs are reasonable
9. Review `data/resources.json` — verify:
   - Resource types are balanced
   - Starting amounts are appropriate
   - Resource nodes are plentiful enough

### PHASE 3: Integration Testing
10. Pull changes from Kali branch
11. Pull changes from Mint branch
12. Merge all branches into main
13. Run full integration test:
    - Start new game
    - Play for 10 minutes
    - Build all building types
    - Train all unit types
    - Research technologies
    - Fight AI opponent
    - Test save/load
    - Test all UI menus

### PHASE 4: Final Polish
14. Fix any integration issues
15. Update `docs/BALANCE_CHANGES.md` with final values
16. Update `AGENTS.md` with new features
17. Create `CHANGELOG.md` with all changes
18. Tag release: `git tag v0.2.0`

### PHASE 5: Export & Deploy
19. Export final APK (if Godot available)
20. Test APK on device
21. Push all changes to main
22. Create pull request if needed

## Git Branch
```bash
cd ~/Workspace/age-of-mitos
git checkout -b improvements-arch
# Make changes
git add -A
git commit -m "feat: coordination, balance, integration"
git push origin improvements-arch
```

## Verification
After each phase, run:
```bash
# Check all JSON files
for f in data/*.json; do python3 -m json.tool "$f" > /dev/null && echo "$f OK" || echo "$f FAILED"; done
# Check all scripts compile
find . -name "*.gd" -exec grep -l "extends\|class_name" {} \; | wc -l
```

## Status Updates
Update `docs/ARCH_STATUS.md` after each phase with:
- What was completed
- Balance changes made
- Integration results
- Any blockers or issues
