# MINT — FASES 7-8: INTERFAZ + ANDROID

Tu trabajo: hacer que el juego se vea bien y sea jugable en Android.

Lee MASTER_PROMPT.md para contexto completo.

---

## FASE 7 — INTERFAZ COMPLETA (completar 100%)

### Archivos a modificar/crear:
- `scripts/ui/hud.gd` — MEJORAR
- `scripts/ui/selection_panel.gd` — MEJORAR
- `scripts/ui/build_menu.gd` — MEJORAR
- `scripts/ui/train_menu.gd` — MEJORAR
- `scripts/ui/minimap.gd` — MEJORAR
- `scripts/ui/ui_manager.gd` — MEJORAR
- CREAR: `scripts/ui/command_card.gd`
- CREAR: `scripts/ui/tooltip_system.gd`
- CREAR: `scripts/ui/notification_system.gd`
- CREAR: `scripts/ui/error_display.gd`

### 7.1 Panel Contextual Inferior (Command Card)
1. Crear `command_card.gd` que se ubique abajo a la derecha
2. Contenido cambia según selección:
   - **Unidad individual**: nombre, retrato, vida, ataque, armadura, velocidad, estado actual
   - **Múltiples unidades**: iconos agrupados, cantidad por tipo, comandos comunes
   - **Aldeano**: Mover, Detener, Construir, Reparar, Recolectar, Atacar, Patrullar, Mantener
   - **Militar**: Mover, Atacar, Ataque-Movimiento, Detener, Patrullar, Mantener, Formación
   - **Edificio**: Producir, Cancelar, Reunión, Investigar, Reparar, Demoler
3. Botones con iconos (procedural si no hay PNG)
4. Atajos de teclado mostrados en cada botón
5. Botones deshabilitados con razón visible

### 7.2 HUD Mejorado
1. Barra de recursos arriba: iconos + cantidad para Wood, Food, Stone, Gold
2. Indicador de población: actual/máxima
3. Hora de juego
4. Controles de velocidad: 1x, 2x, 3x, Pausa
5. Iconos de recursos con pixel-art procedural (no emojis)

### 7.3 Tooltips
1. Crear `tooltip_system.gd`
2. Al hacer hover sobre cualquier botón → mostrar tooltip
3. Contenido: nombre, descripción, atajo de teclado, costo
4. Posición: evitar que se salga de pantalla
5. Temporizador: aparecer después de 0.5s de hover

### 7.4 Sistema de Notificaciones
1. Crear `notification_system.gd`
2. Mensajes flotantes: "Recursos insuficientes", "Unidad producida", etc.
3. Colores: verde=éxito, rojo=error, amarillo=info
4. Duración configurable
5. Stack de notificaciones (máximo 3 visibles)

### 7.5 Minimapa Mejorado
1. Clic en minimap → mover cámara a esa posición
2. Click derecho en minimap → punto de reunión
3. Colores de terreno: verde=hierba, marrón=tierra, azul=agua
4. Niebla de guerra superpuesta
5. Puntos de unidades: azul=propio, rojo=enemigo, gris=neutral
6. Rectángulo de viewport

### 7.6 Panel de Edificio
1. Crear `scripts/ui/building_panel.gd`
2. Mostrar: nombre, tipo, HP barra, progreso de construcción
3. Cola de producción visible con progreso individual
4. Capacidad de guarnición
5. Tecnologías disponibles
6. Botones de upgrade

### 7.7 Integración con Selection
1. Cuando Kali termine SelectionManager, conectar signals
2. `EventBus.unit_selected` → actualizar panel
3. `EventBus.building_selected` → actualizar panel
4. `EventBus.selection_changed` → actualizar command card
5. Mantener compatibilidad si Kali aún no termina

---

## FASE 8 — CONTROLES ANDROID (completar 100%)

### Archivos a modificar/crear:
- `scripts/core/input_manager.gd` — MEJORAR
- CREAR: `scripts/ui/android_controls.gd`
- CREAR: `scripts/ui/touch_indicator.gd`

### 8.1 Detección de Plataforma
1. Detectar si es Android o desktop
2. En desktop: comportamiento con mouse
3. En Android: comportamiento con toques

### 8.2 Gestos Android
1. **Toque simple** → seleccionar (si toca unidad/edificio) o mover (si toca terreno con selección)
2. **Toque largo** → info/inspección
3. **Arrastre sobre terreno vacío** → rectángulo de selección
4. **Toque en minimap** → mover cámara
5. **Dos dedos arrastrar** → mover cámara (pan)
6. **Pinza** → zoom in/out
7. **Toque fuera de UI** → órdenes
8. **Toque en UI** → interacción con menú

### 8.3 Separación de Gestos
1. Cámara vs Selección: el primer movimiento del dedo determina la acción
2. Si el dedo se mueve más de 10px → es pan de cámara
3. Si el dedo se queda quieto → es toque/selección
4. UI siempre tiene prioridad sobre gestos del mapa

### 8.4 Botones Android
1. Botón grande de cancelar (abajo a la izquierda)
2. Botones de acción contextual (abajo a la derecha)
3. Tamaño mínimo 48dp para toque
4. Feedback visual al tocar

### 8.5 Indicadores Táctiles
1. Crear `touch_indicator.gd`
2. Círculo semitransparente donde toca el usuario
3. Desaparece después de 0.3s
4. Color según acción: azul=selección, verde=mover, rojo=atacar

### 8.6 Rendimiento
1. No ejecutar detección de gestos costosa en cada frame
2. Usar InputEventScreenTouch y InputEventScreenDrag
3. Pool de indicadores
4. Throttle de actualizaciones de UI

### 8.7 Pruebas
1. Crear test que simule toques
2. Verificar que la cámara no se mueve al seleccionar
3. Verificar que la selección múltiple funciona con arrastre
4. Verificar que los botones responden

---

## FLUJO DE TRABAJO

1. Lee MASTER_PROMPT.md
2. Lee el archivo correspondiente a la fase
3. Implementa todo el código
4. Verifica que compile (sin errores de sintaxis)
5. Actualiza tu status en `docs/MINT_STATUS.md`
6. Cuando termines una fase, avísame con "FASE X COMPLETADA"

## GIT
```bash
cd ~/Workspace/age-of-mitos
git checkout main && git pull origin main
git checkout -b fases-7-8-mint
# Trabajar
git add -A && git commit -m "feat: fases 7-8 - interfaz completa, controles Android"
git push origin fases-7-8-mint
```
