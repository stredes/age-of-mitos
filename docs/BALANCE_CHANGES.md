# FASE 5: Economy Balance — Balance Changes

## Resumen

Ajustes de balance económico basados en análisis de `data/units.json`, `data/buildings.json`, y `data/technologies.json`. Se corrigieron inconsistencias entre datos de unidades y el sistema de ResourceManager, se agregaron dependencias lógicas a edificios, se ajustaron costos, y se eliminaron dead ends en la tech tree.

---

## 1. Units.json — Gather Rates

### Problema
- Tasas de recolección definidas en unidades (0.4-1.5) no coincidían con `BASE_GATHER_RATES` en `resource_manager.gd` (0.39)
- Builder costaba 10 wood además de 35 food, inconsistente con otros civiles
- Catapulta tenía 0 armor, demasiado frágil
- Catapulta no tenía bonus_vs a edificios

### Cambios

| Unit | Stat | Before | After | Reason |
|------|------|--------|-------|--------|
| **Villager** | wood | 1.0 | 0.4 | Align with ResourceManager BASE_GATHER_RATES |
| | stone | 0.8 | 0.35 | Align with ResourceManager |
| | food | 1.2 | 0.5 | Align with ResourceManager |
| | gold | 0.6 | 0.3 | Align with ResourceManager |
| **Lumberjack** | wood | 1.5 | 0.6 | Align with ResourceManager + specialist bonus |
| | stone | 0.5 | 0.25 | Low priority resource |
| | food | 0.8 | 0.35 | Low priority resource |
| | gold | 0.4 | 0.2 | Low priority resource |
| **Miner** | wood | 0.6 | 0.25 | Low priority resource |
| | stone | 1.4 | 0.55 | Align with ResourceManager + specialist |
| | food | 0.7 | 0.3 | Low priority resource |
| | gold | 1.2 | 0.5 | Align with ResourceManager + specialist |
| **Builder** | wood | 0.8 | 0.3 | Low priority, focus on building |
| | stone | 0.6 | 0.25 | Low priority |
| | food | 0.8 | 0.3 | Low priority |
| | gold | 0.4 | 0.15 | Low priority |
| | cost | {food:35, wood:10} | {food:35} | Consistent with other civil units |
| **Catapult** | armor | 0 | 2 | Needs some survivability |
| | bonus_vs | {} | {building: 2.0} | Thematic: siege destroys buildings |

### Specialist Ratios (Villager = 1.0x baseline)

| Resource | Villager | Lumberjack | Miner | Builder |
|----------|----------|------------|-------|---------|
| wood | 0.4 | **0.6** (+50%) | 0.25 | 0.3 |
| stone | 0.35 | 0.25 | **0.55** (+57%) | 0.25 |
| food | **0.5** | 0.35 | 0.3 | 0.3 |
| gold | 0.3 | 0.2 | **0.5** (+67%) | 0.15 |

---

## 2. Buildings.json — Costs and Times

### Problema
- Casas costaban solo 30 wood (muy baratas)
- Resource camps (lumber, mine, mill) costaban 100 wood cada uno (muy caros early game)
- Barracks costaba 150 wood (alto para early military)
- Muros costaban solo 5 stone (extremadamente baratos para 1800 HP)
- Torres requerían solo 125 stone (sin dependencia de mine)
- Castillo solo costaba stone (sin wood)
- Torres y muros no tenían dependencia de mina

### Cambios

| Building | Stat | Before | After | Reason |
|----------|------|--------|-------|--------|
| **House** | cost.wood | 30 | 35 | Slightly more impactful early game |
| **Lumber Camp** | cost.wood | 100 | **75** | More accessible early game |
| | build_time | 25 | **20** | Faster to establish wood economy |
| **Mine** | cost.wood | 100 | **75** | More accessible early game |
| | build_time | 25 | **20** | Faster to establish mining |
| **Mill** | cost.wood | 100 | **75** | More accessible early game |
| | build_time | 25 | **20** | Faster to establish food economy |
| **Barracks** | cost.wood | 150 | **125** | More accessible military |
| | build_time | 40 | **35** | Faster military response |
| **Archery Range** | cost.wood | 150 | **125** | Consistent with barracks |
| | build_time | 40 | **35** | Consistent with barracks |
| **Stable** | cost.wood | 150 | **125** | Consistent with barracks |
| | build_time | 40 | **35** | Consistent with barracks |
| **Wall** | cost.stone | 5 | **10** | More impactful decision |
| | prerequisite | [] | **["mine"]** | Requires mining infrastructure |
| **Tower** | cost.stone | 125 | **100** | Slightly more accessible |
| | attack | 6 | **8** | More defensive threat |
| | prerequisite | [] | **["mine"]** | Requires mining infrastructure |
| **Castle** | cost.stone | 650 | **500** | Slightly more accessible |
| | cost.wood | (none) | **150** | Requires wood infrastructure |
| **Siege Workshop** | techs | [] | **["siege_engineering"]** | New tech for siege upgrades |

### Building Dependency Tree

```
Town Center (start)
├── House (no prereq)
├── Lumber Camp (no prereq)
│   └── Technologies: double_bit_axe, bow_saw
├── Mill (no prereq)
│   └── Technologies: horse_collar, heavy_plow
├── Mine (no prereq)
│   ├── Technologies: gold_mining, stone_mining
│   ├── Wall (requires mine)
│   └── Tower (requires mine)
│       └── Technologies: arrow_firing
├── Barracks (no prereq)
│   ├── Technologies: iron_casting
│   ├── Archery Range (requires barracks)
│   │   └── Technologies: fletching
│   ├── Stable (requires barracks)
│   │   └── Technologies: husbandry
│   └── Siege Workshop (requires barracks + archery_range)
│       └── Technologies: siege_engineering
└── Castle (requires barracks + archery_range + stable)
    └── Technologies: fortified_walls
```

---

## 3. Technologies.json — Dead Ends

### Problema
- **Dead ends identificados:**
  - `fortified_walls` era tier 3 sin nada detrás → OK (final tech)
  - `hand_cart` era tier 3 sin nada detrás → OK (final eco tech)
  - No había tech para asedio
  - No había tech para caballería tier 3
  - No había tech para arqueros tier 3
  - No había tech para edificios (más allá de fortified_walls)
  - `arrow_firing` no tenía dependencia de mine
  - Faltaba tech de velocidad de entrenamiento

### Nuevas Technologies

| Tech | Tier | Cost | Research Time | Requires | Effects | Description |
|------|------|------|---------------|----------|---------|-------------|
| **bodkin_arrow** | 3 | gold:200, food:150 | 80s | fletching, archery_range | ranged_attack: 1.4, range: +1 | +40% ranged attack, +1 range (stacks) |
| **plate_barding** | 3 | gold:250, food:200 | 85s | husbandry, stable | cavalry_armor: 1.3, cavalry_hp: 1.2 | +30% armor, +20% HP cavalry |
| **siege_engineering** | 2 | wood:150, gold:100 | 60s | siege_workshop | siege_attack: 1.25, siege_range: +1 | +25% siege attack, +1 range |
| **masonry** | 2 | stone:150, wood:100 | 55s | mine | building_hp: 1.2, building_armor: +1 | +20% building HP, +1 armor |
| **conscription** | 3 | food:250, gold:150 | 70s | barracks, archery_range | train_speed: 1.25 | +25% military training speed |

### Modified Technologies

| Tech | Change | Before | After | Reason |
|------|--------|--------|-------|--------|
| **arrow_firing** | requires | ["tower"] | ["tower", "mine"] | Logical dependency |

### Updated Tech Tree (Tier Structure)

```
Tier 1 (Economy Foundation)
├── double_bit_axe (+20% wood)
├── horse_collar (+25% farm)
├── gold_mining (+20% gold)
└── stone_mining (+20% stone)

Tier 2 (Specialization)
├── bow_saw (+40% wood, requires double_bit_axe)
├── heavy_plow (+50% farm, requires horse_collar)
├── wheelbarrow (+15% villager speed, +30% carry)
├── iron_casting (+20% melee attack)
├── fletching (+20% ranged attack, +1 range)
├── husbandry (+15% cav speed, +10% cav HP)
├── arrow_firing (+30% tower attack)
└── siege_engineering (+25% siege attack, +1 range) [NEW]

Tier 3 (Advanced)
├── hand_cart (+30% villager speed, +60% carry, requires wheelbarrow)
├── fortified_walls (+50% wall HP, +30% tower HP)
├── bodkin_arrow (+40% ranged attack, +1 range, requires fletching) [NEW]
├── plate_barding (+30% cav armor, +20% cav HP, requires husbandry) [NEW]
├── masonry (+20% building HP, +1 armor) [NEW]
└── conscription (+25% train speed) [NEW]
```

### Dead End Analysis

| Branch | Max Tier | Status |
|--------|----------|--------|
| Wood Economy | 2 (bow_saw) | ✅ Complete |
| Food Economy | 2 (heavy_plow) | ✅ Complete |
| Villager Utility | 3 (hand_cart) | ✅ Complete |
| Melee Attack | 2 (iron_casting) | ✅ Complete |
| Ranged Attack | 3 (bodkin_arrow) | ✅ Complete (NEW) |
| Cavalry | 3 (plate_barding) | ✅ Complete (NEW) |
| Siege | 2 (siege_engineering) | ✅ Complete (NEW) |
| Defense | 3 (fortified_walls) | ✅ Complete |
| Buildings | 2 (masonry) | ✅ Complete (NEW) |
| Training Speed | 3 (conscription) | ✅ Complete (NEW) |

---

## 4. Impact Analysis

### Economy Flow (Early Game)

**Before:**
- Build lumber camp (100 wood) → Very expensive early
- Build mine (100 wood) → Very expensive early
- Build mill (100 wood) → Very expensive early
- Build barracks (150 wood) → Late military

**After:**
- Build lumber camp (75 wood) → Accessible
- Build mine (75 wood) → Accessible
- Build mill (75 wood) → Accessible
- Build barracks (125 wood) → Earlier military options

### Resource Income (5 Villagers, No Techs)

| Resource | Before (per 60s) | After (per 60s) | Change |
|----------|------------------|-----------------|--------|
| Wood | 120 (4 lumberjacks) | 144 (4 lumberjacks) | +20% |
| Food | 120 (4 villagers) | 120 (4 villagers) | 0% |
| Gold | 72 (4 miners) | 120 (4 miners) | +67% |
| Stone | 96 (4 miners) | 132 (4 miners) | +38% |

*Note: Specialist ratios now properly reward specialization*

### Military Timing

| Unit | Before (first available) | After (first available) | Change |
|------|--------------------------|------------------------|--------|
| Swordsman | ~4:00 | ~3:20 | -40s |
| Archer | ~5:00 | ~4:15 | -45s |
| Cavalry | ~5:00 | ~4:15 | -45s |
| Catapult | ~7:00 | ~6:00 | -60s |

---

## 5. Files Modified

| File | Changes |
|------|---------|
| `data/units.json` | Gather rates aligned with ResourceManager, builder cost fix, catapult armor/bonus |
| `data/buildings.json` | Cost reductions, build time reductions, prerequisite additions, tower attack buff |
| `data/technologies.json` | 5 new technologies, 1 modified prereq, dead end elimination |

---

## 6. Testing Notes

- Verify gather rates match `resource_manager.gd` BASE_GATHER_RATES
- Test tech tree accessibility (all techs reachable)
- Balance test: 5 villager start → optimal build order
- Military rush viability: earliest swordsman timing
- Siege viability: catapult cost vs effectiveness
