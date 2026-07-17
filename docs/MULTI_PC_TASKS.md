# Age of Mitos — Multi-PC Improvement Plan

## Overview
Improve "Age of Mitos" (Godot 4.4 RTS) to be 100% playable. Each PC handles specific tasks.

## Current State
- 59 GD scripts, 6 scenes, full architecture
- Core systems: AI, combat, buildings, units, economy, UI, save/load, audio, fog of war
- Main loop works: menu → game → select → move → harvest → build → train → combat

## Architecture
- Autoloads: EventBus, GameManager, DataManager, AudioManager
- Units: component-based (Health, Movement, Selection, Combat, Harvest) with state machine
- Buildings: BuildingBase, BuildingManager, ConstructionSystem, ProductionQueue
- AI: AIDirector, AIBuilder, AIEconomy, AIMilitary
- Data: JSON-driven (units.json, buildings.json, resources.json, technologies.json)

## Critical Issues to Fix

### 1. Testing (ALL PCs)
- Create unit tests for all systems
- Test game loop: menu → start → play → win/lose
- Verify all JSON data loads correctly
- Test AI behaviors
- Test save/load system
- Test combat calculations
- Test building construction flow
- Test unit production flow

### 2. Gameplay Balance
- Review unit stats in units.json
- Review building costs/times in buildings.json
- Review technology tree in technologies.json
- Balance economy: resource rates, costs, build times
- Balance combat: damage, HP, armor, speed

### 3. Bug Fixes
- Verify all preload() paths are correct
- Test edge cases: no units, no buildings, destroyed town center
- Test fog of war with different map sizes
- Test pathfinding around obstacles
- Test building placement validation

### 4. UI/UX Improvements
- Main menu: add settings panel, credits
- HUD: improve resource display, add tooltips
- Selection panel: show unit/building info clearly
- Build menu: add building descriptions, costs
- Train menu: show training progress, queue
- Minimap: improve visibility, click to move

### 5. AI Improvements
- AIBuilder: smarter building placement
- AIEconomy: better resource management
- AIMilitary: varied attack strategies
- AIDirector: adaptive difficulty

### 6. Performance
- Object pooling for projectiles, particles
- Chunk loading optimization
- Fog of war performance
- UI rendering optimization

## Deliverables
1. All tests passing
2. Balance document with recommended changes
3. Bug fix commits
4. UI/UX improvement commits
5. AI improvement commits
6. Performance benchmarks

## Git Workflow
- Branch: `improvements`
- Commit messages: `fix:`, `feat:`, `test:`, `balance:`
- Push to origin when complete
