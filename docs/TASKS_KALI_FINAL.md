# KALI — FASES 1-6: MECÁNICA CENTRAL

Tu trabajo: hacer que las unidades respondan correctamente a cada orden del jugador.

Lee MASTER_PROMPT.md para contexto completo.

---

## FASE 1 — SELECCIÓN (hacer primero, completar 100%)

### Archivos a modificar/crear:
- `scripts/selection/selection_manager.gd` — MEJORAR
- `scripts/ui/selection_panel.gd` — MEJORAR
- `scripts/units/unit_base.gd` — VERIFICAR

### Tareas:
1. Selección individual: clic izquierdo selecciona UNA unidad, muestra círculo, actualiza panel
2. Selección múltiple: arrastrar rectángulo, solo unidades propias, ignora recursos/enemigos
3. Selección de edificios: clic en edificio propio, muestra comandos disponibles
4. Shift+clic: agregar/quitar de selección
5. Doble clic: seleccionar todas las unidades del mismo tipo visibles
6. Grupos: Ctrl+1-9 para asignar, 1-9 para recuperar
7. Escape o clic en vacío: deseleccionar todo
8. Botón "Seleccionar aldeanos inactivos"
9. Límite de selección configurable (default 50)
10. Panel contextual: cambiar contenido según selección (unidad/múltiples/edificio)

### Validación:
- Clic en vacío deselecciona
- Clic en enemigo NO lo selecciona (solo inspeccionar)
- Shift+clic agrega sin perder selección actual
- Grupos funcionan con Ctrl+número
- Panel muestra info correcta de cada tipo

---

## FASE 2 — MOVIMIENTO (completar 100%)

### Archivos a modificar/crear:
- `scripts/units/components/movement_component.gd` — MEJORAR
- `scripts/core/pathfinder.gd` — MEJORAR
- `scripts/units/states/move_state.gd` — MEJORAR
- `scripts/units/states/idle_state.gd` — VERIFICAR

### Tareas:
1. Clic derecho en terreno vacío → mover unidades al punto
2. Marcador visual de destino (verde/azul) que aparece y desaparece
3. Formación: calcular posiciones finales para cada unidad del grupo
4. Separación entre unidades (no apilarse)
5. Llegada suave: desacelerar al acercarse al destino
6. Tolerancia de llegada: no fallar si está casi en el punto
7. Recalcular ruta si hay obstáculo nuevo
8. Velocidad modificada por terreno
9. No atravesar edificios
10. No teletransportar unidades

### Validación:
- Unidad llega al punto exacto
- Grupo se distribuye en formación
- No se atoran entre edificios
- Recalculan ruta si hay bloqueo

---

## FASE 3 — TAREAS DE ALDEANOS (completar 100%)

### Archivos a modificar/crear:
- `scripts/units/states/harvest_state.gd` — MEJORAR
- `scripts/units/components/harvest_component.gd` — MEJORAR
- `scripts/units/states/build_state.gd` — MEJORAR
- `scripts/units/states/unit_state.gd` — VERIFICAR

### Tareas:
1. Clic derecho en recurso (árbol/roca/mina/arbusto) → aldeano camina y recolecta
2. Al llenar capacidad → regresa a punto de entrega (town_center/lumber_camp/mine)
3. Deposita recurso → vuelve al recurso original automáticamente
4. Mostrar visualmente el recurso cargado (cambiar sprite/modular)
5. Clic derecho en construcción incompleta → aldeano camina y construye
6. Múltiples aldeanos en una construcción = velocidad aumentada (decreciente)
7. Clic derecho en edificio dañado (con orden reparar activa) → reparar
8. Unidades militares NO deben intentar recolectar
9. Estados claramente definidos: Idle, Move, Harvest, ReturnResource, Build, Repair
10. Cancelar tarea actual al recibir nueva orden

### Validación:
- Aldeano recolecta, transporta, entrega, vuelve
- Múltiples aldeanos aceleran construcción
- Militares ignoran recursos
- Estados no se contradicen

---

## FASE 4 — CONSTRUCCIÓN (completar 100%)

### Archivos a modificar/crear:
- `scripts/ui/build_menu.gd` — MEJORAR
- `scripts/buildings/construction_system.gd` — MEJORAR
- `scripts/buildings/building_manager.gd` — VERIFICAR
- CREAR: `scripts/buildings/ghost_building.gd` — VISTA FANTASMA

### Tareas:
1. Tecla B abre menú de construcción
2. Seleccionar edificio del menú → vista fantasma sigue el cursor
3. Vista verde = válido, rojo = bloqueado
4. Validar: terreno, recursos, espacio, colisión con otros edificios
5. Clic izquierdo para colocar → descuenta recursos, crea fundación
6. Aldeanos seleccionados caminan automáticamente a construir
7. Barra de progreso visible sobre la fundación
8. Al llegar a 100% → edificio se activa
9. Escape cancela antes de colocar
10. Cancelar construcción devuelve % configurable de recursos

### Validación:
- Vista fantasma muestra área correctamente
- No se puede colocar sobre otro edificio
- No se puede colocar sin recursos
- Aldeanos caminan a construir automáticamente
- Progreso avanza según número de constructores

---

## FASE 5 — PRODUCCIÓN (completar 100%)

### Archivos a modificar/crear:
- `scripts/ui/train_menu.gd` — MEJORAR
- `scripts/buildings/production_queue.gd` — MEJORAR

### Tareas:
1. Seleccionar edificio → panel muestra unidades disponibles
2. Clic en unidad → valida recursos y población
3. Descuenta recursos → entra en cola
4. Barra de progreso de la cola
5. Al terminar → unidad aparece cerca del edificio
6. Unidad nueva aparece seleccionable
7. Cancelar producción → devolver recursos
8. Límite de cola (5 por defecto)
9. Mensajes claros: "Recursos insuficientes", "Población máxima"
10. Punto de reunión: establecer con clic derecho desde edificio

### Validación:
- Unidades se producen en orden
- Recursos se descuentan
- Aparcen fuera del edificio, no dentro
- Punto de reunión funciona
- Cancelar devuelve recursos

---

## FASE 6 — COMBATE (completar 100%)

### Archivos a modificar/crear:
- `scripts/combat/combat_manager.gd` — MEJORAR
- `scripts/units/components/combat_component.gd` — MEJORAR
- `scripts/units/states/attack_state.gd` — MEJORAR
- CREAR: `scripts/combat/attack_move_state.gd`

### Tareas:
1. Clic derecho en enemigo → unidades militares atacan
2. Caminar hasta rango de ataque → iniciar ataque
3. Aplicar daño conDamageCalculator
4. Perseguir si el enemigo se aleja (dentro de límite)
5. Detenerse al destruir objetivo
6. Ataque-movimiento (tecla A): avanzar y atacar enemigos encontrados
7. Mantener posición (tecla H): atacar en rango, no perseguir
8. Detener (tecla S): cancelar todo, volver a Idle
9. Feedback: marcador rojo en objetivo, animación de ataque
10. Muerte: animación, desaparecer después de tiempo, limpiar selección

### Validación:
- Ataque directo funciona
- Ataque-movimiento detecta enemigos en ruta
- Mantener posición no persigue
- Detener cancela todo
- Muerte limpia correctamente

---

## FLUJO DE TRABAJO

1. Lee MASTER_PROMPT.md
2. Lee el archivo correspondiente a la fase
3. Implementa todo el código
4. Verifica que compile (sin errores de sintaxis)
5. Actualiza tu status en `docs/KALI_STATUS.md`
6. Cuando termines una fase, avísame con "FASE X COMPLETADA"

## GIT
```bash
cd ~/Workspace/age-of-mitos
git checkout main && git pull origin main
git checkout -b fases-1-6-kali
# Trabajar
git add -A && git commit -m "feat: fases 1-6 - selección, movimiento, aldeanos, construcción, producción, combate"
git push origin fases-1-6-kali
```
