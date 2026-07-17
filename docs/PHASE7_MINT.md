# PHASE 7 - CORE GAMEPLAY (MINT)

## Focus: UI Menus + HUD + Visual Feedback

### Tasks

#### 1. Main Menu Overhaul
Improve `scenes/main/main_menu.gd`:
- Campaign mode (single player story)
- Skirmish mode (custom game setup)
- Multiplayer menu (placeholder)
- Settings panel (audio, video, controls)
- Credits screen
- Animations/transitions between screens

#### 2. Game Setup Screen
Create `scripts/ui/game_setup_screen.gd`:
- Map selection (Small/Medium/Large)
- Player count (1-8)
- AI difficulty (Easy/Normal/Hard/Expert)
- Civilization selection with bonuses
- Game speed setting
- Victory conditions (Conquest, Wonder, Time)

#### 3. In-Game HUD Improvements
Improve `scripts/ui/hud.gd`:
- Top bar: Resources (Wood, Food, Stone, Gold) with icons
- Population counter (current/max)
- Game time display
- Speed controls (1x, 2x, 3x, Pause)
- Minimap with click-to-move
- Bottom panel: Unit info, abilities, commands
- Notification system (alerts, achievements)

#### 4. Selection Panel Overhaul
Improve `scripts/ui/selection_panel.gd`:
- Unit portrait/name
- HP bar with numbers
- Attack/Armor/Speed stats
- Ability bar with cooldown timers
- Command buttons (Stop, Hold, Patrol, Attack)
- Group management (Assign group, Select group)
- Multi-unit panel (show all selected, click to focus)

#### 5. Building Info Panel
Create `scripts/ui/building_panel.gd`:
- Building name/type
- HP bar with construction progress
- Production queue display
- Garrison count/capacity
- Technologies available
- Upgrade buttons
- Rally point indicator

#### 6. Ability Bar UI
Create `scripts/ui/ability_bar.gd`:
- Horizontal bar of ability icons
- Cooldown overlay (gray sweep)
- Mana cost display
- Tooltip on hover (name, description, hotkey)
- Right-click to activate
- Disabled when not enough mana/cooldown

#### 7. Minimap Improvements
Improve `scripts/ui/minimap.gd`:
- Click to move camera
- Right-click to set waypoint
- Terrain colors (green=brown, water=blue)
- Fog of war overlay
- Unit/building dots with correct colors
- Selection rectangle showing viewport

## Git Branch
```bash
cd ~/Workspace/age-of-mitos
git checkout phase6-mint
git pull origin phase6-mint
# Make changes
git add -A
git commit -m "feat: menu overhaul, game setup, HUD improvements, ability bar, minimap"
git push origin phase6-mint
```
