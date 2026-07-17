# Balance Changes — Fase B: Economía Visible

## Resumen de Cambios

### 1. ResourceManager (`scripts/economy/resource_manager.gd`)

**Nuevas funcionalidades:**
- **Income Tracking**: Cálculo de ingresos por minuto por recurso (`get_resource_income_per_minute`, `get_all_resource_income`, `get_total_income_per_minute`)
- **Idle Villager Detection**: Detección de aldeanos ociosos tras 5s sin actividad (`villager_idle_detected` signal, `get_idle_villagers`, `get_idle_villager_count`, `is_villager_idle`)
- **Auto Drop-Off**: Cola automática de entrega de recursos cuando el aldeano llena su capacidad (`queue_auto_drop_off`, `auto_drop_off_completed` signal)

**Constantes agregadas:**
- `INCOME_TRACK_INTERVAL = 1.0` (actualización por segundo)
- `IDLE_DETECTION_INTERVAL = 5.0` (umbral de ociosidad)
- `GATHERABLE_RESOURCES = ["wood", "stone", "food", "gold"]`
- `DROP_OFF_BUILDINGS` mapping por tipo de recurso
- `CARRY_CAPACITY` por tipo de unidad (villager=10, lumberjack=12, miner=8, builder=6)

**Nuevos signals:**
- `villager_idle_detected(villager_id, player_id)`
- `auto_drop_off_completed(villager_id, drop_off_building_id, resource_type, amount)`

**Nuevos métodos públicos:**
- `get_resource_income_per_minute(resource_type, player_id)`
- `get_all_resource_income(player_id)`
- `get_total_income_per_minute(player_id)`
- `get_idle_villagers(player_id)`
- `get_idle_villager_count(player_id)`
- `is_villager_idle(villager_id, player_id)`
- `get_villager_state(villager_id, player_id)`
- `queue_auto_drop_off(villager_id, player_id, resource_type, amount)`
- `get_economy_summary(player_id)` — para UI/HUD

---

### 2. ResourceNode (`scripts/world/resource_node.gd`)

**Nueva funcionalidad:**
- `find_nearest_drop_off(resource_type, player_id)` — Busca el edificio de entrega más cercano (town_center, lumber_camp, mine, mill) para el tipo de recurso y jugador dado.

---

### 3. Buildings Data (`data/buildings.json`)

**Poblacion (pop_add) confirmada:**
- `town_center`: pop_add = 5
- `house`: pop_add = 5
- Otros edificios: pop_add = 0

**Drop-off types confirmados:**
- `town_center`: ["wood", "stone", "food", "gold"] (universal)
- `lumber_camp`: ["wood"]
- `mine`: ["stone", "gold"]
- `mill`: ["food"]

---

### 4. Technologies Data (`data/technologies.json`)

**Edades (Ages) implementadas con prerequisitos:**
| Edad | Tier | Coste | Tiempo | Requiere |
|------|------|-------|--------|----------|
| dark_age | 1 | 500F 200G | 120s | town_center |
| feudal_age | 2 | 800F 300G | 160s | dark_age + town_center + mill + lumber_camp + mine |
| castle_age | 3 | 1200F 500G | 200s | feudal_age + town_center + barracks + archery_range |
| imperial_age | 4 | 2000F 800G | 250s | castle_age + town_center + castle |

**Tecnologías con campo `age` obligatorio:**
- Todas las tecnologías incluyen `age`: "dark_age", "feudal_age", "castle_age", "imperial_age"
- Prerequisitos de tecnología incluyen tecnologías previas y edificios requeridos

---

### 5. Alertas (Pendiente integración UI)

**Alertas implementadas en ResourceManager (via signals):**
- "Aldeano ocioso detectado" → `villager_idle_detected`
- "Entrega automática completada" → `auto_drop_off_completed`

**Alertas por implementar en UI/HUD (Fase B.2):**
- "Población casi llena" (cuando pop_used >= pop_cap * 0.9)
- "Base atacada" (evento de building_damaged / unit_attacked)

---

## Pruebas Recomendadas

1. **Income Tracking**: Verificar que `get_all_resource_income(0)` devuelve valores > 0 cuando hay aldeanos recolectando
2. **Idle Detection**: Dejar aldeano sin órdenes > 5s → signal `villager_idle_detected`
3. **Auto Drop-off**: 
   - Aldeano llena capacidad (10 madera)
   - Llama `queue_auto_drop_off`
   - Verificar movimiento a lumber_camp/town_center más cercano
   - Verificar `auto_drop_off_completed` signal
4. **Edades**: Investigar dark_age → feudal_age → castle_age → imperial_age, verificar desbloqueo de edificios
5. **ResourceNode.find_nearest_drop_off**: Verificar que encuentra el edificio correcto por tipo de recurso

---

## Archivos Modificados

- `scripts/economy/resource_manager.gd` — Core economy tracking
- `scripts/world/resource_node.gd` — Auto drop-off lookup
- `data/buildings.json` — pop_add, drop_off_types (ya existentes)
- `data/technologies.json` — Ages, tech tree con prerequisitos (ya existente)
- `docs/BALANCE_CHANGES.md` — Este documento

---

## Próximos Pasos (Fase B.2 - UI/Alertas)

1. HUD: Mostrar income/min en barra de recursos
2. HUD: Icono/alerta "aldeano ocioso" con botón "ir al ocioso"
3. HUD: Alerta "población casi llena"
4. HUD: Alerta "base atacada" (integra building_damaged / unit_under_attack)
5. Integración tecnologías: TechnologyTree validar prerequisitos de edad