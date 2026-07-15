# Age of Mitos — Roadmap de Gameplay & UX Overhaul

## Estado Actual del Proyecto

### Lo que ya existe y funciona
- **Cámara** (`camera_controller.gd`): Zoom suave, pan con inercia, pinch zoom, doble tap, screen shake, follow target, límites de mapa. **≈70% completo.**
- **Animaciones de unidades** (`unit_animation_controller.gd`): 14 estados (idle, walk, run, attack, harvest, build, carry, hurt, death, celebrate, sleep, fear, victory, mine). Walk bounce, idle micro-animations, hurt flash+knockback, death secuencia. **≈40% completo.**
- **Animaciones de edificios** (`building_animation_controller.gd`): Estados (constructing, active, producing, damaged, burning, destroyed). Humo, fuego, antorchas, banderas, molinos. Construction progress bar. **≈45% completo.**
- **Partículas** (`particle_effects.gd`): 14 efectos con pooling (dust_walk, wood_chop, stone_mine, gold_mine, food_gather, build_construct, combat_impact, arrow_trail, death_burst, building_destroy, fire_smoke, water_splash, heal, level_up). **≈50% completo.**
- **Mundo decorativo** (`decorative_world_animations.gd`): Tree sway, water animation, grass, cloud shadows, bird flocks, ambient animals, day/night cycle. **≈60% completo.**
- **Sprites procedurales** (`procedural_sprite_factory.gd`): Genera sprites pixel-art 32x32 (unidades) y 96x96 (edificios) en runtime. **Funcional como placeholder.**
- **State machine de unidades** (`unit_state_machine.gd`): FSM con enter/exit/update. Estados: Idle, Move, Attack, Build, Harvest, Dead. **Funcional, sin transiciones suaves.**
- **Pathfinding** (`pathfinder.gd`): AStarGrid2D. **Funcional.**
- **EventBus** (`event_bus.gd`): ~35 señales documentadas. **Sólido.**

### Lo que necesita trabajo mayor
- **Movimiento de unidades**: Sin aceleración/desaceleración, sin evitación de colisiones, sin formaciones.
- **Construcción de edificios**: Solo cambia frame de sprite, no hay etapas visuales progresivas (cimientos → andamios → paredes → techo).
- **HUD**: Básico — sin panel de comandos contextual, sin tooltips, sin hotkeys visibles.
- **Selección de unidades**: Solo círculo draw(), sin anillo animado, sin health bar visual en el mundo.
- **Feedback por acción**: Falta sonido y partículas en muchas acciones (selección, orden move, orden attack, completar investigación, etc.).

---

## Roadmap por Fases

### Fase 1: Movimiento y Animación de Unidades (PRIORIDAD ALTA)
**Objetivo:** Que las unidades se sientan vivas y naturales.

**1.1 Transiciones de animación suaves**
- Agregar sistema de crossfade entre animaciones (0.1-0.3s blend)
- No cambiar instantáneamente de idle→walk o walk→attack
- Implementar en `UnitAnimationController` usando modulate alpha o interpolación de frames

**1.2 Idle mejorado**
- Parpadeo (cada 3-6 segundos, ojos se cierran 1 frame)
- Respiración (scale sutil en Y del sprite)
- Weight shifting (posición X se mueve 1px de lado a lado)
- Head movement (rotación micro del sprite)
- Looking around (cada 8-15 segundos, pausa + gira)

**1.3 Walk/Run mejorado**
- Body bounce ya existe, mejorar con curva sinusoidal
- Arm swing proyectado en sprite (ya parcialmente hecho)
- Weapon sway: arma se balancea durante caminata
- Shield movement: escudo se mueve con el cuerpo
- Turn anticipation: antes de girar, el sprite "mira" en la dirección

**1.4 Rotación natural**
- Unidad no gira instantáneamente
- Tween de rotación (0.1-0.2s) al cambiar dirección
- Sprite flip + ligera inclinación

**1.5 Acceleración/Deceleración**
- En `MovementComponent`: velocity ramp-up y ramp-down
- No empezar a caminar a velocidad máxima
- Frenar suavemente al llegar al destino

**Archivos a modificar:**
- `scripts/animation/unit_animation_controller.gd`
- `scripts/units/components/movement_component.gd`
- `scripts/units/states/move_state.gd`
- `scripts/animation/procedural_sprite_factory.gd` (más frames para nuevas animaciones)

---

### Fase 2: Construcción Progresiva de Edificios (PRIORIDAD ALTA)
**Objetivo:** Edificios se construyen visualmente en etapas, no aparecen de golpe.

**2.1 Cuatro etapas visuales**
- **Etapa 1 (0-25%)**: Preparación del suelo + cimientos. Partículas de polvo. Workers golpeando.
- **Etapa 2 (25-50%)**: Andamios de madera aparecen. Animación de martillo. Sonido de construcción.
- **Etapa 3 (50-85%)**: Paredes suben progresivamente. Techo aparece. Detalles visibles.
- **Etapa 4 (85-100%)**: Decoraciones finales. Humo de chimenea. Bandera. Luz. Sonido de completado.

**2.2 Visual match con progreso**
- `BuildingAnimationController.set_construction_progress()` ya existe pero solo cambia frame
- Agregar sub-nodos visibles por etapa: cimientos (Sprite2D), andamios (Sprite2D), paredes, techo
- Cada etapa tiene su propio conjunto de sprites/efectos

**2.3 Completación de construcción**
- Flash de luz sutil
- Partículas de polvo expandiéndose
- Camera shake (muy leve, 2px, 0.15s)
- Sonido de completado
- Bandera se levanta
- Humo de chimenea activado
- Glow temporal en el edificio

**Archivos a modificar:**
- `scripts/animation/building_animation_controller.gd`
- `scripts/buildings/building_base.gd`
- `scripts/animation/procedural_sprite_factory.gd` (frames de construcción por etapa)

---

### Fase 3: Cámara Mejorada (PRIORIDAD MEDIA)
**Objetivo:** Controles de cámara profesionales tipo AoE2.

**3.1 Edge scrolling**
- Detectar posición del mouse cerca de los bordes de pantalla
- Mover cámara en esa dirección
- Velocidad proporcional a la distancia del borde

**3.2 Keyboard scrolling**
- Flechas / WASD para mover la cámara
- Velocidad ajustable

**3.3 Zoom con límites y suavidad**
- Ya existe smooth zoom, verificar que la interpolación sea perfecta
- Agregar zoom-to-cursor (hacer zoom centrándose donde está el mouse)

**3.4 Camera shake mejorado**
- Ya existe `shake()`, verificar que funcione con todas las acciones relevantes
- Shake al completar construcción, shake al recibir daño, shake al disparar catapulta

**3.5 Double-click follow**
- Doble click en unidad = seguir esa unidad
- Ya existe detección de double-tap, falta el follow

**Archivos a modificar:**
- `scripts/core/camera_controller.gd`

---

### Fase 4: HUD y Panel de Comandos Contextual (PRIORIDAD ALTA)
**Objetivo:** Interfaz profesional tipo RTS clásico.

**4.1 Resource bar (parte superior)**
- Icono + cantidad para cada recurso (madera, piedra, oro, comida)
- Población actual / máximo
- Actualización en tiempo real via EventBus

**4.2 Panel de comandos (parte inferior)**
- Se actualiza según la selección actual:
  - **Aldeano seleccionado**: Construir, Reparar, Recoger, Detener, Mover
  - **Unidad militar seleccionada**: Atacar, Patrullar, Mantener posición, Detener, Formación, Habilidad especial
  - **Edificio seleccionado**: Entrenar unidades, Investigar, Punto de rally, Destruir, Reparar, Cancelar cola
- Cada botón con: icono, tooltip, hotkey visual, estado disabled, feedback al hover/press

**4.3 Selection info panel**
- Mostrar: nombre, tipo, HP bar, stats, cola de producción (si aplica)

**4.4 Minimap**
- Ya existe `minimap.gd`, mejorar con:
  - Puntos de unidades/edificios coloreados
  - Vista de la cámara actual (rectángulo)
  - Click para mover cámara

**4.5 Notifications**
- Popup temporal: "Construcción completada", "Unidad entrenada", "Investigación completada"
- Icono + texto + auto-hide después de 3-5 segundos

**Archivos a crear/modificar:**
- `scripts/ui/ui_manager.gd` (reestructurar)
- `scripts/ui/hud.gd` (resource bar, notifications)
- `scripts/ui/selection_panel.gd` (info panel mejorado)
- `scenes/ui/` (nuevas escenas de UI)
- Nuevo: `scripts/ui/command_panel.gd`
- Nuevo: `scripts/ui/resource_bar.gd`
- Nuevo: `scripts/ui/notification_system.gd`

---

### Fase 5: Efectos de Partículas Mejorados (PRIORIDAD MEDIA)
**Objetivo:** Todo debe generar feedback visual.

**5.1 Partículas faltantes**
- Selection burst (al seleccionar unidad/edificio)
- Move confirmation (flecha o mark en el suelo)
- Attack impact mejorado (chispas de espada, impacto de flecha)
- Construction dust por etapa
- Resource drop-off (brillo al depositar)
- Research complete (glow ascendente)
- Unit spawn (flash de aparición)

**5.2 Mejoras a existentes**
- `dust_walk`: Más variación, menos partículas en unidades lentas
- `combat_impact`: Añadir chispas de metal
- `death_burst`: Añadir polvo que se asienta
- `building_destroy`: Más escombros, duración más larga

**Archivos a modificar:**
- `scripts/animation/particle_effects.gd`
- Integrar en: `unit_animation_controller.gd`, `building_animation_controller.gd`, `build_state.gd`, `harvest_state.gd`

---

### Fase 6: Formaciones y Movimiento Grupal (PRIORIDAD MEDIA)
**Objetivo:** Unidades se mueven en formación, no como个体散乱.

**6.1 Formaciones básicas**
- Línea (por defecto para ataque)
- Columna (para movimiento largo)
- Cuadro (defensivo)
- Círculo (protección)

**6.2 Cálculo de posiciones**
- Cada formación calcula posiciones relativas al líder
- Unidades se mueven a su posición asignada
- Auto-reorganización después de combate

**6.3 Colisión y evitación**
- Boids-like separation (empuje entre unidades cercanas)
- No superponer sprites
- Spacing natural

**Archivos a crear/modificar:**
- Nuevo: `scripts/units/formation_system.gd`
- `scripts/units/components/movement_component.gd`
- `scripts/units/states/move_state.gd`

---

### Fase 7: Menú de Construcción y Recursos (PRIORIDAD MEDIA)
**Objetivo:** Build menu profesional con categorías y previews.

**7.1 Categorías del build menu**
- Economía (casa, molino, campamento madera, campamento mina)
- Militar (cuartel, rango arquero, establo, taller asedios)
- Defensa (torre, castillo, muralla)
- Tecnología (universidad, monasterio)
- (Futuro: Religión, Naval, Maravilla)

**7.2 Info por edificio en el menú**
- Preview visual (sprite pequeño)
- Costo (iconos de recursos)
- Tiempo de construcción
- Requisitos (edificio previo)
- Impacto en población
- Descripción
- Hotkey
- Razón de indisponibilidad (si no se puede construir)

**7.3 Recolección de recursos mejorada**
- Villager walk to resource → harvest → carry visible → return to storage → unload → auto-repeat
- Animaciones diferenciadas por recurso (ya parcialmente hecho)
- Partículas por tipo de recurso (ya existen)

**Archivos a modificar:**
- `scripts/ui/build_menu.gd`
- `scripts/units/states/harvest_state.gd`
- `scripts/units/components/harvest_component.gd`

---

### Fase 8: Polish Visual del Mundo (PRIORIDAD BAJA)
**Objetivo:** Nada debe parecer estático.

**8.1 Ya existe en `decorative_world_animations.gd`:**
- Tree sway ✓
- Water animation ✓
- Grass animation ✓
- Cloud shadows ✓
- Bird flocks ✓
- Ambient animals ✓
- Day/night cycle ✓

**8.2 Por agregar**
- Animated flags en edificios (parcialmente hecho)
- Smoke de chimenea en casas
- Torch fire mejorado
- Water ripples en ríos
- Wind effect en vegetación
- Building idle animations (ventanas brillando, gente caminando)

**Archivos a modificar:**
- `scripts/animation/decorative_world_animations.gd`
- `scripts/animation/building_animation_controller.gd`

---

### Fase 9: Feedback Completo por Acción (PRIORIDAD MEDIA)
**Objetivo:** Cada interacción del jugador genera respuesta inmediata.

**9.1 Acciones que necesitan feedback**
| Acción | Animación | Sonido | Partículas | UI |
|--------|-----------|--------|------------|-----|
| Click selección | ✓ Anillo | ✓ Click | ✓ Selection burst | ✓ Panel info |
| Orden move | ✓ Walk | ✓ Acknowledge | ✓ Move mark | ✓ Mark en suelo |
| Orden attack | ✓ Attack | ✓ Battle cry | ✓ Attack mark | ✓ Target highlight |
| Completar construcción | ✓ Active anim | ✓ Fanfare | ✓ Dust cloud | ✓ Notification |
| Entrenar unidad | ✓ Spawn anim | ✓ Spawn sound | ✓ Flash | ✓ Notification |
| Investigar tech | — | ✓ Research sound | ✓ Glow | ✓ Notification |
| Recibir daño | ✓ Hurt | ✓ Hit sound | ✓ Blood/sparks | ✓ HP flash |
| Morir | ✓ Death | ✓ Death sound | ✓ Death burst | ✓ Unit消失 |
| Recoger recurso | ✓ Harvest | ✓ Gather sound | ✓ Resource particles | — |
| Depósito recurso | ✓ Carry→Idle | ✓ Deposit sound | ✓ Deposit glow | ✓ Resource update |

**Archivos a modificar:**
- Todos los scripts de estados de unidades
- `scripts/ui/notification_system.gd` (nuevo)
- `autoload/audio_manager.gd` (nuevos sonidos)

---

### Fase 10: Performance para Android (PRIORIDAD ALTA)
**Objetivo:** 60 FPS en Android.

**10.1 Optimizaciones**
- Object pooling para partículas (ya existe en `particle_effects.gd`)
- MultiMeshInstance2D para unidades/edificios del mismo tipo
- Visibility culling (solo actualizar lo visible en cámara)
- Chunk updates para animaciones del mundo
- LOD simulation (unidades lejanas usan animaciones simplificadas)
- Throttling de updates (ya parcialmente hecho en decorative_world_animations)

**10.2 Medición**
- Agregar FPS counter visible en debug
- Profile en Android real
- Identificar cuellos de botella

---

### Fase 11: Code Quality (PRIORIDAD BAJA)
**Objetivo:** Código mantenible y escalable.

**11.1 Typed GDScript**
- Agregar tipos explícitos a todas las variables y parámetros
- Usar `-> void`, `-> int`, `-> String`, etc. en todas las funciones

**11.2 Documentación**
- Comentarios en cada clase nueva
- Comentarios en funciones públicas
- Actualizar AGENTS.md con cada cambio

**11.3 SOLID**
- Revisar responsabilidades de cada script
- Separar si un script hace demasiado
- Composition over inheritance

---

## Orden de Ejecución Recomendado

1. **Fase 1** (Animaciones) → Mayor impacto visual inmediato
2. **Fase 3** (Cámara) → Quick win, ya casi completa
3. **Fase 2** (Construcción) → Segundo mayor impacto visual
4. **Fase 5** (Partículas) → Complementa Fases 1-3
5. **Fase 4** (HUD) → Mayor impacto en UX
6. **Fase 9** (Feedback) → Pulido general
7. **Fase 7** (Build menu + recursos) → Gameplay
8. **Fase 6** (Formaciones) → Avanzado
9. **Fase 8** (Mundo decorativo) → Polish
10. **Fase 10** (Performance) → Optimización
11. **Fase 11** (Code quality) → Mantenimiento

---

## Convenciones del Proyecto

### GDScript
- Usar `class_name` en todas las clases
- Typed GDScript donde sea posible
- Signals para comunicación entre sistemas
- No duplicar lógica, usar composición

### Architectura
- Autoloads: EventBus, GameManager, DataManager, AudioManager
- Componentes: Health, Movement, Selection, Combat, Harvest
- States: UnitState-based FSM
- Data-driven: JSON en `data/`

### Sprites
- Procedurales como placeholder hasta tener PNGs reales
- Pixel-art style, 32x32 unidades, 96x96 edificios
- Color palette: player colors (azul, rojo, verde, amarillo)

### Export
- Android Debug APK
- Godot 4.4.1 headless
- No Gradle (standard export)
- Debug keystore

### Rutas de Herramientas
- Godot: `tools/Godot_v4.4.1-stable_win64.exe`
- Android SDK: `C:\android-sdk`
- Java: `C:\jdk-17`
- Keystore: `C:\Users\bodega 1\AppData\Roaming\Godot\keystores\debug.keystore`
