# PHASE 7 - CORE GAMEPLAY (KALI)

## Focus: Unit Abilities + Combat Systems

### Tasks

#### 1. Ability System (CRITICAL)
Create `scripts/units/ability_system.gd`:
- Each unit type has unique abilities
- Abilities have cooldowns, mana costs, ranges
- Active abilities: heal, rally, charge, stun, poison, shield
- Passive abilities: regeneration, speed boost, damage resistance
- Ability bar UI integration

#### 2. Unit Abilities by Type
Add ability definitions in `data/abilities.json`:
- **Villager**: Build faster, Gather boost, Repair
- **Warrior**: Charge (dash + damage), War cry (AOE stun), Shield wall
- **Archer**: Volley (multi-shot), Poison arrows, Eagle eye (extended range)
- **Cavalry**: Trample (AOE), Scout (extended vision), Ride by (hit and run)
- **Priest**: Heal, Resurrect, Holy shield
- **Siege**: Bombard (AOE), Demolish (extra building damage)

#### 3. Selection System Improvements
Improve `scripts/selection/selection_manager.gd`:
- Double-click select all of type on screen
- Ctrl+click to add/remove from selection
- Group selection (1-9 keys to assign, 0 to deselect)
- Selection circle with unit count for groups
- Show abilities of selected units in ability bar

#### 4. Movement System Improvements
Improve `scripts/units/components/movement_component.gd`:
- Right-click ground = move to position
- Right-click enemy = attack move
- Right-click friendly = follow
- Shift+right-click = queue movement orders
- Formation movement when multiple units selected
- Avoid walking through buildings

#### 5. Command Card System
Create `scripts/ui/command_card.gd`:
- Bottom-right panel showing available commands
- Updates based on selected unit/building
- Shows ability icons with cooldown overlays
- Right-click abilities for quick cast
- Keyboard shortcuts displayed on each button

#### 6. Context Menu System
Create `scripts/ui/context_menu.gd`:
- Right-click context menus on units/buildings
- Gather, Garrison, Patrol, Guard options
- Building-specific options (rally point, garrison, set stance)

## Git Branch
```bash
cd ~/Workspace/age-of-mitos
git checkout phase6-kali
git pull origin phase6-kali
# Make changes
git add -A
git commit -m "feat: ability system, command card, selection groups, movement improvements"
git push origin phase6-kali
```
