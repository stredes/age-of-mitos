# TASK LIST FOR KALI (PC 2) — Age of Mitos

## Your Role: Core Systems + Testing
Focus on: AI, Combat, Economy, Unit Systems, and comprehensive testing.

## Tasks (in order)

### PHASE 1: Analysis & Testing
1. Read ALL scripts in `scripts/ai/` — document what each does, find bugs
2. Read ALL scripts in `scripts/combat/` — verify damage calculations
3. Read ALL scripts in `scripts/units/` — verify state machine, components
4. Read `scripts/economy/resource_manager.gd` — verify resource flows
5. Create test files in `tests/` for each system:
   - `tests/test_ai_director.gd`
   - `tests/test_ai_economy.gd`
   - `tests/test_ai_military.gd`
   - `tests/test_ai_builder.gd`
   - `tests/test_combat_manager.gd`
   - `tests/test_damage_calculator.gd`
   - `tests/test_unit_states.gd`
   - `tests/test_resource_manager.gd`

### PHASE 2: Bug Fixes
6. Fix any bugs found in AI systems
7. Fix any bugs found in combat system
8. Fix any bugs found in unit state machine
9. Fix any bugs found in economy system
10. Verify all EventBus connections work correctly

### PHASE 3: AI Improvements
11. Improve `ai_director.gd` — add personality types (aggressive, defensive, balanced)
12. Improve `ai_economy.gd` — better resource balancing, market trading
13. Improve `ai_military.gd` — varied attack formations, retreat logic
14. Improve `ai_builder.gd` — smarter placement, defense structures

### PHASE 4: Combat Improvements
15. Improve `combat_manager.gd` — area damage, multi-target
16. Improve `damage_calculator.gd` — terrain bonuses, morale
17. Improve `projectile.gd` — different projectile types

### PHASE 5: Economy Balance
18. Review `data/units.json` — adjust villager gather rates
19. Review `data/buildings.json` — adjust costs, build times
20. Review `data/technologies.json` — verify tech tree is complete
21. Create `docs/BALANCE_CHANGES.md` with all recommended changes

## Git Branch
```bash
cd ~/Workspace/age-of-mitos
git checkout -b improvements-kali
# Make changes
git add -A
git commit -m "feat: AI, combat, economy improvements and tests"
git push origin improvements-kali
```

## Verification
After each phase, run:
```bash
# Check for syntax errors
find . -name "*.gd" -exec grep -l "extends\|class_name" {} \; | head -20
# Verify JSON loads
cat data/units.json | python3 -m json.tool > /dev/null && echo "units.json OK"
cat data/buildings.json | python3 -m json.tool > /dev/null && echo "buildings.json OK"
```

## Status Updates
Update `docs/KALI_STATUS.md` after each phase with:
- What was completed
- What bugs were found/fixed
- What improvements were made
- Any blockers or issues
