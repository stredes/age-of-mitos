# MINT — AOE-LIKE RTS: UI + ANDROID + POLISH

Eres el agente de Mint. Tu trabajo: hacer que el juego se vea y se sienta como AoE en Android.

Lee MASTER_PROMPT.md para contexto general.

---

## TUS RESPONSABILIDADES (UI + Touch + Minimap + HUD)

### FASE 1 — CONTROLES TÁCTILES ANDROID (Completar 100%)

Archivos a crear/modificar:
- `scripts/core/input_manager.gd` — MEJORAR
- `scripts/core/camera_controller.gd` — MEJORAR
- CREAR: `scripts/ui/android_touch_controls.gd`
- CREAR: `scripts/ui/touch_indicator.gd`
- `project.godot` — CONFIGURAR

Tareas:
1. Detectar plataforma: Android vs Desktop
2. En Android:
   - Tap = seleccionar (si toca unidad/edificio) o mover (si toca terreno con selección)
   - Drag con 1 dedo sobre terreno vacío = rectángulo de selección
   - 2 dedos arrastrar = pan cámara
   - Pinch = zoom in/out
   - Long press = menú contextual secundario
3. Separar gestos de cámara vs selección:
   - Primer movimiento >10px = pan de cámara
   - Primer movimiento ≤10px = toque/selección
4. UI siempre tiene prioridad sobre gestos del mapa
5. Crear `touch_indicator.gd`: círculo semitransparente donde toca (0.3s, colores por acción)
6. Crear `android_touch_controls.gd`: botones grandes de cancelar, contextual
7. Tamaño mínimo 48dp para toque
8. Configurar enable_pan_and_scale_gestures en project.godot

### FASE 2 — HUD ECONÓMICO COMPLETO (Completar 100%)

Archivos a crear/modificar:
- `scripts/ui/hud.gd` — MEJORAR COMPLETAMENTE
- `scripts/ui/ui_manager.gd` — MEJORAR
- CREAR: `scripts/ui/resource_icon_factory.gd`
- CREAR: `scripts/ui/quick_action_bar.gd`
- CREAR: `scripts/ui/population_display.gd`

Tareas:
1. Barra superior: recursos con iconos pixel-art (no emojis) + cantidad
2. Indicador de población: actual/máxima, alerta visual antes del cap
3. Indicador de era/edad actual
4. Income display: ingresos estimados por segundo por recurso
5. Idle villager count con botón para seleccionar todos los ociosos
6. Quick actions: botones fijos para Town Center, aldeano ocioso, ejército, constructor
7. Speed controls: 1x, 2x, 3x, Pausa
8. Resource icon factory: generar iconos procedurales para wood/food/stone/gold

### FASE 3 — MINIMAPA TÁCTICO (Completar 100%)

Archivos a crear/modificar:
- `scripts/ui/minimap.gd` — REESCRIBIR

Tareas:
1. Click en minimap → mover cámara a esa posición
2. Click derecho en minimap → punto de reunión
3. Colores de terreno: verde=hierba, marrón=tierra, azul=agua
4. Niebla de guerra superpuesta
5. Puntos de unidades: azul=propio, rojo=enemigo, gris=neutral
6. Tamaño de punto: unidad=2px, edificio=4px
7. Rectángulo de viewport actual
8. Filtros: toggle eco/militar/recursos
9. Alertas de ataque: flash rojo en minimap
10. Expandible: botón para agrandar temporalmente

### FASE 4 — PANEL CONTEXTUAL + COMANDOS (Completar 100%)

Archivos a crear/modificar:
- `scripts/ui/selection_panel.gd` — REESCRIBIR
- `scripts/ui/command_card.gd` — MEJORAR
- `scripts/ui/building_panel.gd` — MEJORAR
- CREAR: `scripts/ui/unit_portrait.gd`
- CREAR: `scripts/ui/stance_button.gd`

Tareas:
1. Panel contextual inferior que cambia según selección:
   - **1 unidad**: retrato, nombre, HP bar, stats (ataque/armadura/velocidad), estado
   - **Múltiples**: iconos agrupados, cantidad por tipo, comandos comunes
   - **Aldeano**: Mover, Detener, Construir, Reparar, Recolectar, Atacar, Patrullar, Mantener
   - **Militar**: Mover, Atacar, Ataque-Movimiento, Detener, Patrullar, Mantener, Formación
   - **Edificio**: Producir, Cancelar, Reunión, Investigar, Reparar, Demoler
2. Command card con iconos claros, atajos de teclado visibles
3. Botones deshabilitados con razón visible (recursos, población, etc.)
4. Unit portrait procedural
5. Stance button: Aggressive/Defensive/Passive toggle
6. Tooltips en hover/long-press

### FASE 5 — TOOLTIPS + NOTIFICACIONES + ERRORES (Completar 100%)

Archivos a crear/modificar:
- `scripts/ui/tooltip_system.gd` — MEJORAR
- `scripts/ui/notification_system.gd` — MEJORAR
- CREAR: `scripts/ui/error_display.gd`
- CREAR: `scripts/ui/victory_defeat_screen.gd`

Tareas:
1. Tooltips: aparecer 0.5s después de hover, nombre + descripción + atajo + costo
2. Notificaciones: mensajes flotantes (verde=éxito, rojo=error, amarillo=info), stack de 3
3. Error display: "No hay suficiente madera", "Ubicación bloqueada", "Población máxima"
4. Victory/defeat screen con stats resumidas
5. Rally point visual: línea desde edificio hasta punto

### FASE 6 — PRUEBAS Y RENDIMIENTO ANDROID

1. Verificar que tap selecciona correctamente
2. Verificar que drag-box selecciona múltiples
3. Verificar que 2 dedos mueven cámara sin seleccionar
4. Verificar que pinch hace zoom
5. Verificar que UI responde en todos los tamaños
6. Medir FPS en Android durante combate
7. Verificar que no hay memory leaks en UI
8. Exportar APK y probar

## GIT
```bash
cd ~/Workspace/age-of-mitos
git checkout main && git pull origin main
git checkout -b aoe-ui-mint
# Trabajar
git add -A && git commit -m "feat: aoe ui - touch controls, HUD, minimap, panels, tooltips"
git push origin aoe-ui-mint
```
