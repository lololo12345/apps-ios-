# Bastión: el valle de la Niebla

Aventura y construcción para iPhone, en horizontal. Llevas a un pequeño Brote por el valle: recoges madera, bayas,
piedra y setas, las vendes en el mercado, fabricas productos que valen más, mejoras tu equipo y tu base, construyes
puentes para cruzar el río y defiendes la hoguera de la Niebla cada noche.

## Qué incluye (primera entrega)
- **Mundo con dos zonas**: el Claro y el Bosque Viejo, separados por un río; más allá, la Cantera en la Niebla
  (próxima entrega). Mapa de 64 × 30 casillas con 140 árboles, arbustos, rocas, setas y árboles dorados.
- **Recoger**: tu Brote recoge solo lo que tiene cerca. Rachas (cada 8 golpes seguidos, uno extra), árboles dorados
  con troncos de oro, mochila con límite.
- **Base**: al entrar se guarda todo en el almacén. Mercado con precios que cambian cada día y un producto estrella,
  taller para fabricar (tablas, tartas, ladrillos, guisos), huerto que crece también con el juego cerrado, torres y
  empalizada.
- **Equipo**: hacha, mochila, botas, espada y armadura, 6 niveles cada uno.
- **Puentes**: se pagan poco a poco con madera, piedra y monedas, y se construyen tabla a tabla.
- **Enemigos**: babosas y lobos de la Niebla en el bosque; golpe automático y golpe fuerte ⚡.
- **Noches**: cada noche la Niebla asalta la hoguera; las torres disparan. Si aguantas, recompensa; si no, roban
  parte del almacén.
- **Jefe**: el Gran Lobo de Humo guarda el segundo río. Avisa antes de embestir y, a media vida, aúlla y llama a
  dos lobos.
- **Siempre un objetivo**: 14 misiones guiadas, 12 logros, encargos de los vecinos cada día y regalo diario con racha.
- Día y noche, luciérnagas, hojas, chispas, números de daño, vibración y apariencia clara/oscura de los paneles.

## Proyecto
- `BastionKit/`: reglas del juego (objetos, recetas, mercado, equipo, edificios, mapa, enemigos, noches, misiones,
  partida guardada). Solo Foundation: se comprueba y se simula en Linux.
- `Bastion/Game/`: el mundo en SpriteKit (`WorldScene`), el arte dibujado con código (`Art`), la interfaz en SwiftUI
  con cristal de iOS 26 (`GameScreen`, `Panels`) y el puente entre ambos (`GameModel`).
- Tests: reglas con Swift Testing y siete recorridos por la interfaz con capturas.

Todo se guarda solo en el iPhone, sin cuentas.
