# MASTER PROMPT — CONTROL JUGABLE RTS PARA AGE OF MITOS

Actúa como un desarrollador senior especializado en videojuegos RTS, Godot 4.4.1, GDScript, arquitectura modular, UX para estrategia en tiempo real y optimización para Android.

Trabaja directamente sobre el proyecto existente **Age of Mitos**.

El objetivo principal es implementar y mejorar un sistema completamente jugable en el que el usuario humano pueda:

* seleccionar unidades;
* seleccionar múltiples unidades;
* seleccionar edificios;
* mover unidades;
* enviar aldeanos a recolectar;
* ordenar construcciones;
* asignar constructores;
* atacar enemigos;
* producir unidades;
* cancelar órdenes;
* controlar formaciones;
* administrar recursos;
* interactuar con el mundo mediante clics o toques.

El juego no debe jugar automáticamente por el usuario.

Las unidades solo deben ejecutar las órdenes entregadas por el jugador.

La prioridad actual no es mejorar la IA enemiga. La prioridad es lograr que el jugador pueda controlar correctamente todas las unidades, trabajadores, ejércitos y edificios.

---

## Objetivo de experiencia

Age of Mitos debe sentirse como un RTS clásico inspirado en la usabilidad de:

* Age of Empires II Definitive Edition;
* Age of Mythology;
* Warcraft III;
* Stronghold;
* Rise of Nations.

No copiar recursos, diseños ni contenido protegido.

Tomar solamente como referencia la claridad de controles, la respuesta de las unidades, la selección, los paneles contextuales y la gestión de órdenes.

El jugador debe poder realizar todas las acciones importantes desde el mapa y desde un panel contextual.

Cada clic debe producir una respuesta clara.

---

## Principio principal

El jugador humano toma todas las decisiones estratégicas.

Las unidades únicamente ejecutan órdenes.

Ejemplos:

* El jugador selecciona un aldeano.
* El jugador hace clic en un árbol.
* El aldeano camina hacia el árbol.
* El aldeano comienza a recolectar madera.
* Cuando llena su capacidad, entrega el recurso.
* Luego vuelve al mismo recurso mientras siga disponible.

Esto no significa que la IA juegue por el usuario.

Es solamente comportamiento interno necesario para completar una orden.

La unidad no debe cambiar de trabajo, construir, atacar o explorar sin que el jugador lo ordene.

---

## 1. Sistema de selección

Implementar un sistema de selección completo y robusto.

### Selección individual

Al hacer clic izquierdo o tocar una unidad propia:

* seleccionar solamente esa unidad;
* mostrar un círculo de selección;
* mostrar su información en el panel inferior;
* mostrar vida, nombre, estado y estadísticas;
* reproducir feedback visual;
* reproducir sonido de selección si está disponible.

Al hacer clic en un edificio propio:

* seleccionar el edificio;
* mostrar sus comandos disponibles;
* mostrar producción, vida, progreso o mejoras;
* ocultar comandos que no correspondan.

### Selección múltiple

Permitir seleccionar varias unidades arrastrando un rectángulo sobre el mapa.

El rectángulo debe:

* aparecer mientras se arrastra;
* seleccionar únicamente unidades propias;
* ignorar recursos, decoraciones y enemigos;
* mostrar cuántas unidades quedaron seleccionadas;
* actualizar el panel contextual.

### Selección adicional

Implementar:

* Shift + clic para agregar o quitar unidades;
* doble clic para seleccionar unidades visibles del mismo tipo;
* grupos de control con Ctrl + números;
* números para recuperar grupos;
* selección prioritaria de unidades por sobre edificios;
* botón para seleccionar aldeanos inactivos;
* botón para seleccionar unidades militares;
* límite configurable de selección.

### Reglas

No permitir controlar unidades enemigas.

Unidades enemigas solamente pueden inspeccionarse o marcarse como objetivo.

La selección debe mantenerse hasta que:

* el jugador seleccione otra cosa;
* presione Escape;
* toque un área vacía;
* la unidad muera;
* el jugador use una orden de deselección.

---

## 2. Órdenes mediante clic derecho o toque contextual

Implementar órdenes contextuales según el objeto sobre el que el jugador haga clic.

### Terreno vacío

Si hay unidades seleccionadas y el jugador hace clic derecho en el suelo:

* mover las unidades;
* mostrar un marcador de destino;
* calcular rutas;
* distribuir las unidades en formación;
* evitar que todas intenten ocupar el mismo punto.

### Recurso natural

Si hay aldeanos seleccionados y el jugador hace clic en un recurso:

* asignar la tarea correspondiente;
* caminar hasta un punto válido;
* iniciar animación de recolección;
* aumentar recurso transportado;
* mostrar visualmente el recurso cargado;
* regresar a un punto de entrega;
* depositar recursos;
* volver al recurso original.

Tipos:

* árbol → madera;
* roca → piedra;
* mina → oro;
* arbusto o animal → alimento.

Las unidades militares no deben intentar recolectar.

### Edificio en construcción

Si hay aldeanos seleccionados y el jugador hace clic en una construcción incompleta:

* caminar hacia el edificio;
* encontrar una posición disponible;
* comenzar a construir;
* aumentar progresivamente el avance;
* permitir varios constructores;
* aumentar la velocidad según cantidad de trabajadores;
* mostrar animación y partículas de construcción.

### Edificio dañado

Si el jugador activa la orden Reparar y selecciona un edificio propio:

* enviar aldeanos;
* gastar recursos cuando corresponda;
* restaurar vida progresivamente;
* mostrar martilleo y partículas.

### Unidad o edificio enemigo

Si hay unidades militares seleccionadas:

* ejecutar una orden de ataque;
* caminar hasta rango de ataque;
* iniciar animación;
* aplicar daño;
* perseguir dentro de un límite razonable;
* detenerse si el objetivo muere o queda inaccesible.

Si hay aldeanos seleccionados:

* permitir ataque solo si el diseño del aldeano lo admite;
* usar daño reducido;
* no reemplazar automáticamente su trabajo anterior.

### Unidad aliada

Según el tipo de unidad:

* seguir;
* proteger;
* acompañar;
* reparar si corresponde;
* entrar en transporte en futuras versiones.

---

## 3. Estado y tareas de las unidades

Cada unidad debe tener un estado claramente definido.

Estados mínimos:

* Idle;
* Move;
* Harvest;
* ReturnResource;
* Build;
* Repair;
* Attack;
* AttackMove;
* Patrol;
* Follow;
* HoldPosition;
* Stop;
* Hurt;
* Dead.

No permitir estados contradictorios.

Ejemplo:

Una unidad no puede atacar y recolectar simultáneamente.

Al recibir una nueva orden:

1. cancelar correctamente la orden anterior;
2. limpiar objetivos anteriores;
3. actualizar el estado;
4. calcular la nueva ruta;
5. iniciar la animación correspondiente;
6. actualizar el panel de selección.

---

## 4. Movimiento de unidades

Mejorar `MovementComponent` y `Pathfinder`.

Implementar:

* aceleración;
* desaceleración;
* giro suave;
* rutas usando AStarGrid2D;
* actualización de ruta si aparece un obstáculo;
* separación entre unidades;
* evitación local;
* reducción de atascos;
* agrupamiento por formación;
* llegada suave al destino;
* tolerancia de llegada;
* movimiento sobre terreno válido;
* velocidad modificada por terreno.

No teletransportar unidades.

No mover unidades en línea recta atravesando edificios.

No ejecutar navegación costosa para todas las unidades en cada frame.

Las rutas deben recalcularse solamente cuando sea necesario.

---

## 5. Formaciones

Reemplazar la distribución cuadrada básica por un sistema modular de formaciones.

Implementar inicialmente:

* cuadrado;
* línea;
* columna;
* dispersa;
* compacta.

Cuando varias unidades reciben una orden de movimiento:

1. calcular el centro del grupo;
2. determinar la dirección hacia el destino;
3. generar posiciones finales;
4. asignar una posición distinta a cada unidad;
5. evitar cruces innecesarios;
6. conservar distancia mínima;
7. adaptar la formación si hay obstáculos.

La formación no debe impedir que las unidades lleguen al destino.

Priorizar siempre funcionalidad sobre rigidez visual.

---

## 6. Construcción de edificios

Implementar un flujo de construcción completamente controlado por el jugador.

### Flujo

1. El jugador selecciona uno o más aldeanos.
2. Presiona el botón Construir o la tecla B.
3. Se abre el menú de edificios.
4. El jugador selecciona un edificio.
5. Aparece una vista fantasma.
6. El jugador mueve la vista fantasma por el mapa.
7. El sistema valida terreno, recursos y espacio.
8. El jugador confirma con clic.
9. Se descuentan los recursos.
10. Se crea la fundación.
11. Los aldeanos seleccionados caminan hacia ella.
12. Comienza la construcción progresiva.
13. El edificio se activa al llegar al 100%.

### Vista fantasma

Debe indicar:

* verde si es válido;
* rojo si está bloqueado;
* área ocupada;
* tamaño en la grilla;
* colisión con recursos;
* colisión con edificios;
* límites del mapa;
* terreno no permitido.

### Cancelación

Permitir:

* cancelar antes de colocar;
* cancelar durante la construcción;
* devolver un porcentaje configurable;
* liberar las celdas de la grilla;
* detener a los constructores;
* eliminar correctamente la fundación.

### Constructores múltiples

Cada aldeano adicional debe aumentar la velocidad, pero con rendimiento decreciente configurable.

Ejemplo conceptual:

* 1 constructor → velocidad base;
* 2 constructores → mejora considerable;
* 5 constructores → no multiplicar exactamente por cinco;
* establecer un máximo útil.

---

## 7. Producción de unidades

Los edificios deben permitir producir unidades mediante botones.

### Flujo

1. El jugador selecciona un edificio.
2. El panel muestra las unidades disponibles.
3. El jugador presiona una unidad.
4. Se validan recursos y población.
5. Se descuentan recursos.
6. La unidad entra en la cola.
7. Aparece el progreso.
8. Al terminar, la unidad aparece cerca del edificio.
9. La nueva unidad queda disponible para seleccionar.

### Cola de producción

Implementar:

* varias unidades en cola;
* icono por unidad;
* cantidad;
* progreso;
* tiempo restante;
* cancelación;
* devolución parcial o total configurable;
* límite de cola;
* mensaje de población máxima;
* mensaje de recursos insuficientes;
* punto de reunión.

### Punto de reunión

El jugador debe poder establecer un punto de reunión desde el edificio.

Las unidades recién creadas deben:

* aparecer en una posición válida;
* caminar hacia el punto de reunión;
* no quedar dentro del edificio;
* no aparecer sobre otras unidades;
* no aparecer fuera del mapa.

---

## 8. Panel contextual inferior

Construir o mejorar un panel inspirado en RTS clásicos.

El contenido debe cambiar según la selección.

### Unidad individual

Mostrar:

* nombre;
* retrato;
* vida;
* ataque;
* armadura;
* velocidad;
* tarea actual;
* recurso transportado;
* botones disponibles.

### Múltiples unidades

Mostrar:

* iconos agrupados;
* cantidad por tipo;
* vida aproximada o individual;
* comandos comunes;
* formación seleccionada.

### Aldeanos

Comandos:

* mover;
* detener;
* construir;
* reparar;
* recolectar;
* atacar;
* patrullar;
* mantener posición.

### Unidad militar

Comandos:

* mover;
* atacar;
* ataque-movimiento;
* detener;
* patrullar;
* mantener posición;
* cambiar formación.

### Edificio

Comandos:

* producir unidades;
* cancelar producción;
* establecer punto de reunión;
* investigar;
* reparar;
* demoler.

### Estados deshabilitados

Cuando un botón no se pueda usar, mostrar el motivo:

* recursos insuficientes;
* población máxima;
* tecnología no investigada;
* edificio incompleto;
* no hay aldeanos seleccionados;
* terreno inválido;
* acción no disponible.

---

## 9. Órdenes fundamentales

Implementar comandos centrales reutilizables.

Usar un sistema de órdenes como:

```gdscript
class_name UnitCommand
extends RefCounted

enum CommandType {
    MOVE,
    ATTACK,
    ATTACK_MOVE,
    HARVEST,
    BUILD,
    REPAIR,
    PATROL,
    FOLLOW,
    HOLD_POSITION,
    STOP
}

var command_type: CommandType
var target_position: Vector2
var target_entity: Node
var queued: bool = false
```

No duplicar lógica de órdenes en cada botón.

El panel, teclado, mouse y controles táctiles deben enviar comandos al mismo sistema central.

Arquitectura recomendada:

```
InputManager
    ↓
SelectionManager
    ↓
CommandManager
    ↓
UnitCommand
    ↓
UnitStateMachine
    ↓
Movement / Combat / Harvest / Build Components
```

---

## 10. Sistema de ataque

El jugador debe poder ordenar ataques de diferentes maneras.

### Ataque directo

* seleccionar unidades;
* hacer clic sobre enemigo;
* mostrar marcador rojo;
* acercarse hasta rango;
* atacar;
* aplicar daño;
* detenerse al destruir el objetivo.

### Ataque-movimiento

* presionar botón o tecla;
* seleccionar un punto;
* avanzar hacia el punto;
* atacar enemigos encontrados dentro del rango de detección;
* continuar después del combate si todavía existe la orden.

### Mantener posición

* atacar enemigos dentro del rango;
* no perseguir lejos;
* volver a la posición asignada.

### Detener

* cancelar movimiento;
* cancelar ataque;
* cancelar patrulla;
* pasar a estado Idle;
* no eliminar automáticamente la selección.

---

## 11. Feedback de órdenes

Cada orden debe mostrar feedback inmediato.

### Movimiento

* marcador verde o azul;
* sonido;
* breve animación;
* línea opcional de ruta para depuración.

### Ataque

* marcador rojo;
* cursor de ataque;
* sonido;
* resaltado del objetivo.

### Recolección

* marcador del color del recurso;
* icono correspondiente;
* confirmación del aldeano.

### Construcción

* vista fantasma;
* celdas ocupadas;
* barra de progreso;
* partículas;
* sonido de martillo;
* efecto al completar.

### Error

Mostrar mensajes claros:

* "No hay suficiente madera".
* "Ubicación bloqueada".
* "Selecciona un aldeano".
* "Límite de población alcanzado".
* "No existe una ruta válida".
* "Este edificio aún está en construcción".

Nunca fallar silenciosamente.

---

## 12. Controles de escritorio

Implementar:

* clic izquierdo → seleccionar;
* arrastrar clic izquierdo → selección múltiple;
* Shift + clic → añadir o quitar selección;
* clic derecho en terreno → mover;
* clic derecho en recurso → recolectar;
* clic derecho en enemigo → atacar;
* clic derecho en construcción → construir;
* B → abrir menú de construcción;
* S → detener;
* A → ataque-movimiento;
* P → patrullar;
* H → mantener posición;
* Escape → cancelar orden o menú;
* Delete → demolición con confirmación;
* Ctrl + número → crear grupo;
* número → seleccionar grupo.

Evitar conflictos entre acciones.

Actualmente WASD debe permanecer reservado para comandos si así lo define el proyecto.

---

## 13. Controles Android

La versión Android debe permitir jugar sin mouse.

Implementar:

* toque → seleccionar;
* toque fuera → cambiar selección;
* arrastre iniciado sobre terreno vacío → rectángulo de selección;
* toque sobre terreno con unidades seleccionadas → mover;
* toque sobre enemigo → atacar;
* toque sobre recurso → recolectar;
* toque sobre construcción → construir o reparar;
* dos dedos → mover cámara;
* gesto de pinza → zoom;
* botón visible para cancelar;
* botones suficientemente grandes;
* modo de orden activo claramente visible.

Evitar que mover la cámara seleccione unidades accidentalmente.

Separar correctamente:

* gestos de cámara;
* selección;
* emisión de órdenes;
* interacción con UI.

---

## 14. Orden de implementación obligatorio

Trabajar en este orden:

### Fase 1 — Selección

* selección individual;
* selección múltiple;
* selección de edificios;
* anillos;
* panel básico;
* deselección.

### Fase 2 — Movimiento

* clic derecho;
* marcador;
* rutas;
* movimiento grupal;
* separación;
* llegada.

### Fase 3 — Tareas de aldeanos

* recolección;
* transporte;
* entrega;
* construcción;
* reparación;
* estados visibles.

### Fase 4 — Construcción

* menú;
* vista fantasma;
* validación;
* costos;
* fundación;
* progreso;
* finalización.

### Fase 5 — Producción

* selección de edificios;
* botones;
* costos;
* cola;
* progreso;
* aparición;
* punto de reunión.

### Fase 6 — Combate

* ataque directo;
* ataque-movimiento;
* daño;
* muerte;
* persecución limitada;
* feedback.

### Fase 7 — Interfaz completa

* panel contextual;
* tooltips;
* atajos;
* errores;
* minimapa;
* cola visual.

### Fase 8 — Android

* controles táctiles;
* gestos;
* botones;
* rendimiento;
* pruebas con APK.

No avanzar a una fase si la anterior no es completamente jugable.

---

## 15. Integración con la arquitectura existente

Reutilizar:

* `SelectionManager`;
* `GameWorld`;
* `InputManager`;
* `UnitBase`;
* `UnitStateMachine`;
* `MovementComponent`;
* `HarvestComponent`;
* `CombatComponent`;
* `BuildingManager`;
* `ConstructionSystem`;
* `ProductionQueue`;
* `GridManager`;
* `Pathfinder`;
* `ResourceManager`;
* `EventBus`;
* `SelectionPanel`;
* `BuildMenu`;
* `TrainMenu`.

No crear sistemas duplicados si ya existe uno reutilizable.

Antes de modificar:

1. inspeccionar scripts;
2. identificar responsabilidades;
3. detectar errores;
4. refactorizar solamente cuando sea necesario;
5. conservar compatibilidad;
6. validar escenas;
7. validar señales;
8. probar desde el flujo completo del jugador.

---

## 16. Restricciones técnicas

* Godot 4.4.1.
* Usar APIs compatibles con Godot 4.4.
* Mantener `gl_compatibility`.
* Mantener exportación Android.
* Evitar asignaciones innecesarias por frame.
* No usar búsquedas globales repetidas con `get_tree().get_nodes_in_group()` dentro de `_process()`.
* No crear partículas nuevas repetidamente.
* Usar pooling.
* Usar señales para cambios de estado.
* Evitar dependencias circulares.
* No colocar lógica estratégica en la interfaz.
* No colocar lógica visual dentro de los gestores de economía.
* No agregar código de demostración sin integración real.

---

## 17. Validación de cada implementación

Después de cada fase:

1. ejecutar el proyecto;
2. revisar errores del debugger;
3. probar con una unidad;
4. probar con múltiples unidades;
5. probar clics rápidos;
6. probar cancelación;
7. probar objetivos destruidos;
8. probar rutas bloqueadas;
9. probar selección durante movimiento;
10. probar selección durante combate;
11. probar edificios incompletos;
12. probar recursos agotados;
13. probar población máxima;
14. probar desde Android o emulación táctil;
15. exportar APK.

No considerar una función terminada únicamente porque compila.

Debe funcionar dentro de una partida real.

---

## 18. Formato de respuesta del agente

Antes de programar, entregar:

1. diagnóstico del sistema actual;
2. archivos que serán modificados;
3. dependencias;
4. riesgos;
5. plan de implementación.

Por cada archivo modificado, explicar brevemente:

* qué se cambió;
* por qué;
* cómo se integra;
* cómo se prueba.

No limitarse a entregar recomendaciones.

Escribir código funcional, comentado y compatible con Godot 4.4.1.

---

## Resultado esperado

Al finalizar, el usuario debe poder iniciar una partida y ejecutar este flujo completo:

1. seleccionar un aldeano;
2. enviarlo a recolectar madera;
3. seleccionar varios aldeanos;
4. abrir el menú de construcción;
5. colocar un edificio;
6. asignar los aldeanos como constructores;
7. observar el avance;
8. seleccionar el edificio terminado;
9. producir unidades;
10. establecer un punto de reunión;
11. seleccionar las nuevas unidades;
12. moverlas en formación;
13. atacar una unidad o edificio enemigo;
14. detenerlas;
15. cambiarles de objetivo;
16. controlar todo mediante clics o toques.

El juego debe responder a las decisiones del jugador humano.

Las unidades deben obedecer, ejecutar y mostrar claramente cada tarea asignada.

La IA no debe sustituir el control del jugador.

Este prompt se concentra primero en construir un **RTS realmente jugable**, desde seleccionar un aldeano hasta producir y controlar un ejército, dejando la IA enemiga como una capa posterior.
