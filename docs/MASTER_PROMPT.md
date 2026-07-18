# Prompt maestro para adaptar Age of Mitos a un RTS móvil estilo Age of Empires con estética WorldBox

## Resumen ejecutivo
La investigación apunta a una convergencia clara: Age of Mitos debe tomar de Age of Empires II: Definitive Edition la claridad operativa del RTS clásico —paneles contextuales, puntos de reunión, feedback de órdenes, legibilidad de tecnología y adaptación moderna de controles— y de WorldBox la sensación de "mundo vivo" en pixel art —civilizaciones visibles sobre el mapa, crecimiento orgánico, casas/caminos, guerra, múltiples capas de meta-información y una interfaz que privilegia la interacción directa sobre el terreno—, todo ello llevado a una implementación jugable por clic/tap, no automatizada por IA, sobre Godot 4.4.1 con foco prioritario en Android.

## Principios de diseño obligatorios

### 1. RTS primero
- economía, construcción, exploración, control de ejército, producción, combate, presión táctica, lectura rápida del mapa

### 2. Mundo vivo sin pérdida de legibilidad
- microanimaciones, partículas ligeras, clima, decorativos animados
- nunca sacrificar siluetas, contraste, claridad de selección

### 3. Móvil primero, escritorio completo
- touch como input principal
- mouse, teclado, stylus como alternativas

### 4. Arquitectura escalable
- InputManager → SelectionManager → CommandManager → UnitCommand → StateMachine → Components → EventBus/UI

---

## Sistemas a implementar

### A. Selección
- individual, múltiple por caja, de edificios, prioridad, por tipo, grupos de control, aldeanos inactivos, anillos y resaltados

### B. Órdenes y comando contextual
- move, stop, hold, attack, attack-move, patrol, harvest, return resources, build, repair, rally point, cancel
- Todas pasan por CommandManager común

### C. Estados de unidad
- Idle, Move, Harvest, ReturnResource, Build, Repair, Attack, AttackMove, Patrol, Follow, HoldPosition, Hurt, Dead, Celebrate, Fear

### D. Movimiento y navegación
- AStarGrid2D, region configurable, re-path por eventos, aceleración/desaceleración, turn smoothing, local avoidance, terrain modifiers

### E. Formaciones
- compacta, línea, columna, dispersa, cuadrada
- degradación con obstáculos, llegada orgánica

### F. Recolección y economía
- flujo: orden → recurso → animación → partículas → recurso transportado → drop-off → regreso automático
- recursos: madera, piedra, oro, alimento

### G. Construcción
- ghost footprint → validación → foundation → constructores → progresión visual → activación → cancelación con refund

### H. Producción de unidades
- panel de building, cola visible, costo, tiempo, población, spawn válido, rally point, cancelación

### I. Combate
- adquisición por orden, rango, pursuit leash, daño, hurt, muerte, feedback, attack-move, hold position

### J. UI / HUD
- barra recursos, panel contextual inferior, retratos, botones grandes, cola producción, tooltips, minimapa, notificaciones, población

### K. Cámara
- pan por arrastre/borde, zoom por pinza, suavizado, límites, shake, recentrado

### L. Audio
- feedback selección, confirmación orden, error, construcción, producción, impacto, ambiente

### M. Partículas y feedback
- footsteps, harvest, sparks, hit flash, death, construction, completion, weather, smoke/fire

### N. Animación procedural y pixel sandbox
- microanimación constante, sprite frames cortos, bounce sutil, 8 direcciones, partículas vendiendo acciones

### O. Pipeline de arte
- manifest obligatorio, batch generation, snake_case, PNG transparente, perspectiva 45°, palette mediterránea

### P. Performance Android
- pooling, culling, throttling decorativo, quality tiers, 60 FPS target

---

## Especificaciones de animación WorldBox adaptada

| Acción | Frames | Tempo |
|--------|--------|-------|
| Idle unidad | 2–4 | 180–320 ms/frame |
| Walk | 4–6 | 80–120 ms/frame |
| Attack melee | 3–5 | 180–320 ms total |
| Harvest/Build | 3–5 | 95–140 ms/frame |
| Hurt | 1–2 | 60–90 ms/frame |
| Death | 4–6 | 80–120 ms/frame |
| Building ambience | 2–4 | 300–900 ms/frame |
| Construction stages | 3–5 | progreso discreto |

---

## JSON Examples

### Unidad
```json
{
  "unit_id": "villager",
  "display_name": "Aldeano",
  "category": "worker",
  "max_hp": 60,
  "speed": 62.0,
  "acceleration": 240.0,
  "deceleration": 260.0,
  "turn_speed": 8.0,
  "collision_radius": 6,
  "selection_radius": 10,
  "gather_rates": { "wood": 0.42, "stone": 0.30, "gold": 0.28, "food": 0.38 },
  "carry_capacity": { "wood": 10, "stone": 10, "gold": 10, "food": 10 },
  "build_speed": 1.0,
  "can_attack": true,
  "attack": { "damage": 3, "cooldown": 1.3, "range": 12, "pursuit_leash": 64 },
  "train_time": 12.0,
  "cost": { "food": 50, "wood": 0, "gold": 0, "stone": 0 },
  "anim_spec": "villager_base"
}
```

### Edificio
```json
{
  "building_id": "town_center",
  "display_name": "Centro urbano",
  "category": "economic_core",
  "size": { "x": 4, "y": 4 },
  "max_hp": 1800,
  "build_time": 75.0,
  "foundation_blocking": true,
  "drop_off_types": ["wood", "food", "gold", "stone"],
  "trainable_units": ["villager"],
  "queue_limit": 10,
  "cost": { "wood": 275, "stone": 100, "gold": 0, "food": 0 },
  "rally_point_default": { "x": 0, "y": 48 },
  "construction_stages": 4,
  "anim_spec": "town_center_base"
}
```

### Recurso
```json
{
  "resource_id": "tree_oak",
  "resource_type": "wood",
  "max_amount": 125,
  "depletion_behavior": "stump_then_remove",
  "harvest_slots": 3,
  "anim_spec": "tree_oak_ambient"
}
```

### Comando
```json
{
  "command_type": "HARVEST",
  "queued": false,
  "target_entity_ref": "resource_184",
  "target_position": { "x": 512, "y": 288 },
  "formation_mode": "loose",
  "issued_by": "player_local"
}
```

### Formación
```json
{
  "formation_id": "line",
  "spacing": 18,
  "row_size": 8,
  "depth_bias": 0.4,
  "obstacle_degrade_mode": "adaptive"
}
```

### Anim Spec
```json
{
  "anim_spec_id": "villager_base",
  "sprite_size": 32,
  "directions": 8,
  "actions": {
    "idle": { "frames": 3, "frame_ms": 220, "bounce_px": 1 },
    "walk": { "frames": 4, "frame_ms": 90, "bounce_px": 1 },
    "harvest": { "frames": 4, "frame_ms": 110, "impact_frame": 2 },
    "build": { "frames": 4, "frame_ms": 105, "impact_frame": 2 },
    "attack": { "frames": 3, "frame_ms": 85, "impact_frame": 2 },
    "hurt": { "frames": 2, "frame_ms": 70 },
    "death": { "frames": 5, "frame_ms": 95 }
  },
  "carry_layers": ["wood_bundle", "stone_sack", "gold_sack", "food_crate"]
}
```

---

## Roadmap

| Fase | Fecha | Contenido |
|------|-------|-----------|
| 1 | 2026-07-19 | Selección y feedback base |
| 2 | 2026-07-26 | Órdenes move/stop + path |
| 3 | 2026-08-02 | Harvest + retorno + drop-off |
| 4 | 2026-08-09 | Construcción completa |
| 5 | 2026-08-16 | Cola unidades + rally point |
| 6 | 2026-08-23 | Combate + attack-move + death |
| 7 | 2026-08-30 | HUD completo + errores + tooltips |
| 8 | 2026-09-06 | Animación sandbox + VFX + audio |
| 9 | 2026-09-13 | Optimización Android + export QA |
| 10+ | 2026-09-20+ | Núcleo jugable → Producción → Capa visual |

---

## Criterio de éxito final

El jugador debe poder:
1. Seleccionar aldeanos
2. Enviarlos a recolectar
3. Construir un edificio
4. Terminarlo con varios workers
5. Producir unidades
6. Fijar rally point
7. Seleccionar ejército
8. Moverlo en formación
9. Atacar
10. Detener
11. Reordenar
12. Hacerlo todo mediante click/tap con feedback claro y buen rendimiento en Android

Prioridad: legibilidad RTS > control humano > rendimiento Android > mantenibilidad
