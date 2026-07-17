# KALI — AOE-LIKE RTS: MECÁNICAS CORE

Eres el agente de Kali. Tu trabajo: hacer que las mecánicas del juego funcionen como Age of Empires.

Lee MASTER_PROMPT.md para contexto general.

---

## TUS RESPONSABILIDADES (Mecánicas + Combate + IA)

### FASE A — VERBOS DEL JUGADOR (Completar 100%)

Archivos a crear/modificar:
- `scripts/combat/attack_move_state.gd` — NUEVO
- `scripts/units/states/patrol_state.gd` — NUEVO
- `scripts/units/states/hold_state.gd` — NUEVO
- `scripts/units/states/repair_state.gd` — NUEVO
- `scripts/units/states/return_resource_state.gd` — NUEVO
- `scripts/combat/unit_command.gd` — NUEVO (sistema central de órdenes)
- `scripts/combat/command_manager.gd` — NUEVO
- `scripts/units/unit_state_machine.gd` — MEJORAR
- `scripts/units/components/movement_component.gd` — MEJORAR
- `scripts/core/pathfinder.gd` — MEJORAR

Tareas:
1. Crear `unit_command.gd` con CommandType enum: MOVE, ATTACK, ATTACK_MOVE, HARVEST, BUILD, REPAIR, PATROL, FOLLOW, HOLD_POSITION, STOP
2. Crear `command_manager.gd` que reciba input del SelectionManager y emita comandos
3. Crear `attack_move_state.gd`: avanzar hacia punto, atacar enemigos detectados en rango, continuar después
4. Crear `patrol_state.gd`: ir y volver entre 2 puntos, atacar enemigos en ruta
5. Crear `hold_state.gd`: atacar enemigos en rango, no perseguir, volver a posición
6. Crear `repair_state.gd`: aldeano repara edificio dañado, gasta recursos
7. Crear `return_resource_state.gd`: llevar recurso a drop-off, depositar, volver al recurso
8. Mejorar `unit_state_machine.gd`: cancelar correctamente estado anterior, limpiar objetivos
9. Mejorar `movement_component.gd`: separación entre unidades, evitación local, llegada suave
10. Mejorar `pathfinder.gd`: recalcular solo cuando sea necesario, no cada frame

### FASE B — ECONOMÍA VISIBLE (Completar 100%)

Archivos a crear/modificar:
- `scripts/economy/resource_manager.gd` — MEJORAR
- `scripts/world/resource_node.gd` — MEJORAR
- `data/buildings.json` — MEJORAR (agregar garrison, population cap por casa)
- `data/technologies.json` — MEJORAR (tech tree con eras)

Tareas:
1. Agregar tracking de ingresos por segundo en ResourceManager
2. Agregar "idle villager" detection
3. Agregar drop-off automático en town_center, lumber_camp, mine, mill
4. Agregar pop_add por house en buildings.json
5. Agregar eras/edades en technologies.json (Feudal, Castle, Imperial equivalentes)
6. Agregar prerequisitos de edificio para tecnología
7. Agregar alerts: "población casi llena", "aldeano ocioso", "base atacada"

### FASE C — COMBATE PROFUNDO (Completar 100%)

Archivos a crear/modificar:
- `scripts/combat/damage_calculator.gd` — MEJORAR
- `scripts/combat/combat_manager.gd` — MEJORAR
- `scripts/combat/projectile.gd` — MEJORAR
- `scripts/units/components/combat_component.gd` — MEJORAR
- `data/units.json` — MEJORAR (agregar armor_melee, armor_ranged, bonus_vs tags)

Tareas:
1. Consolidar HP, daño, armadura melee/ranged en DamageCalculator
2. Agregar counters por tipo: infantería > caballería, arqueros > infantería, caballería > arqueros
3. Agregar bonus_vs en units.json para cada tipo
4. Mejorar proyectiles: velocidad, trayectoria, impacto visual
5. Agregar line_of_sight por unidad
6. Agregar feedback: hit flash, daño numérico opcional, screen shake sutil

### FASE D — IA RIVAL MODULAR (Completar 100%)

Archivos a crear/modificar:
- `scripts/ai/ai_director.gd` — MEJORAR
- `scripts/ai/ai_economy.gd` — MEJORAR
- `scripts/ai/ai_builder.gd` — MEJORAR
- `scripts/ai/ai_military.gd` — MEJORAR

Tareas:
1. IA respeta fog of war: no reaccione a unidades fuera de visión
2. IA tiene personalidades: aggressive, defensive, balanced, turtle
3. IA hace build orders predefinidas
4. IA scouts al inicio
5. IA defensa: construye torres si es atacada
6. IA ejército: entrena counter-units según composición enemiga
7. IA target selection: ataca unidades/economía, no solo lo más cercano
8. Tiempos de reacción plausibles (no reacciona instantáneamente)

### FASE E — INTEGRACIÓN Y TESTING

1. Verificar que attack-move funciona con múltiples unidades
2. Verificar que patrol recorre los puntos y ataca
3. Verificar que hold position no persigue
4. Verificar que economy loop completo funciona: recolectar → transportar → depositar → volver
5. Verificar que IA no hace trampas (misma economía, misma información)
6. Exportar test: atacar con 5 unidades vs 5 unidades IA
7. Verificar FPS durante combate

## GIT
```bash
cd ~/Workspace/age-of-mitos
git checkout main && git pull origin main
git checkout -b aoe-mechanics-kali
# Trabajar
git add -A && git commit -m "feat: aoe mechanics - verbs, economy, combat, AI"
git push origin aoe-mechanics-kali
```
