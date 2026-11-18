# Instrucciones para Claude

## Antes de crear una app nueva
0. Ofrece siempre 5 ideas de apps distintas, cada una en una o dos líneas, para que el usuario elija.
1. Cuando elija una, presenta la propuesta de forma breve: problema que resuelve y para quién, funcionalidades,
   pantallas, tecnologías y qué queda fuera del alcance.
2. Espera a que el usuario la acepte explícitamente. Si pide cambios, ajusta la propuesta y vuelve a presentarla.
3. Solo después de la aceptación, empieza a desarrollar.

## Plataformas
- Cuando el usuario pida una app nueva, pregúntale SIEMPRE para qué plataforma la quiere: iPhone, Android o las dos.
  Hazlo antes de presentar la propuesta, y que la propuesta refleje la elección.
- iPhone: SwiftUI, carpeta `<App>/` creada con `tools/new_ios_app.py` (ver el flujo abajo). Se entrega el `.ipa`.
- Android: Kotlin + Jetpack Compose, carpeta `<App>Android/` creada con `tools/new_android_app.py` (ver el flujo
  abajo). Se entrega el `.apk`.
- Si más adelante pide la otra plataforma de una app ya hecha, pórtala con las mismas funciones y contenido.

## Repositorio
- Todo el trabajo de apps (iPhone y Android) va en este repositorio (`lololo12345/apps-ios-`).
- No uses el repositorio `Historias-Tiktok`: es para otra cosa.

## Cómo construir una app de iPhone (flujo)
1. `python3 tools/new_ios_app.py <Nombre> <bundle.id> --display "…" --summary "…" --accent HEX --background HEX [--kit] [--widget] [--dark]`
   crea la app completa, compilable y con tests (diseño base, icono provisional, ajustes, utilidades de UI tests,
   README) y la añade al índice. La CI la detecta sola: no hay que tocar `ios.yml`.
2. La lógica va en `<App>Kit/` (solo Foundation) y se comprueba aquí en segundos con `tools/check_swift.sh <App>`.
   Para probar contenido y generadores a fondo: `tools/check_swift.sh --run <App> script.swift`.
3. Push a `main`: la CI solo compila y prueba las apps que han cambiado (`tools/ci_plan.py`). Si cambian `tools/`
   o el workflow, prueba todas y además genera y prueba «Plantilla» para garantizar que el generador funciona.
4. Revisa SIEMPRE las capturas antes de entregar: `python3 -I tools/contact_sheet.py <carpeta> hoja.jpg`.
   Avisa solo de capturas casi vacías (a mitad de animación) o repetidas (un toque que no hizo nada); además, míralas:
   textos cortados, solapes, contraste, datos vacíos. Si algo se ve mal, se arregla antes de entregar.
5. Entrega el `.ipa` solo de un commit con la CI en verde, y comprueba que el widget va dentro (`Payload/<App>.app/PlugIns`).
6. Actualiza el README de la app con las mejores capturas (`<App>/docs/screenshots/`).

## Cómo construir una app de Android (flujo)
1. `python3 tools/new_android_app.py <Nombre> <application.id> --display "…" --summary "…" --accent HEX --background HEX`
   crea `<Nombre>Android/` completa: Gradle con las mismas versiones que RondaAndroid (`tools/android/`), clave de
   firma propia, tema oscuro con tarjetas de cristal, navegación inferior, ajustes guardados, tests de lógica y de
   interfaz con capturas (Robolectric + Roborazzi) y README.
2. Aquí se puede compilar y probar todo: `cd <Nombre>Android && ./gradlew testDebugUnitTest assembleRelease --offline`
   (SDK en `/root/android-sdk`). Capturas en `app/build/screenshots`; revísalas con `tools/contact_sheet.py`.
3. La CI (`android.yml`) solo prueba las apps Android que han cambiado y, si cambia el generador, crea y prueba
   «PlantillaAndroid».
4. Si es el port de una app de iPhone: mismas funciones y contenido; la lógica del `<App>Kit` se traduce a `core/`.

## Lista de calidad (lo aprendido en Relato, Ronda, Plan B, Isla y Chispa)
**Diseño y fluidez**
- iOS 26 con Liquid Glass (`glassEffect`, `.buttonStyle(.glass/.glassProminent)`), 120 Hz activado en el Info.plist.
- Fondos con gradientes radiales, nunca `blur` a pantalla completa (mantiene los 120 Hz).
- Animaciones con `.smooth`/`.snappy`/`.spring`, `contentTransition(.numericText())` en números, `symbolEffect` en iconos
  y `sensoryFeedback` (con opción de desactivarlo en Ajustes).
- Fechas en español: `sentenceCased`, nunca `.capitalized` («Domingo, 15 De Noviembre» está mal).
- Margen lateral de 16 pt; nada de scroll horizontal accidental; prueba los textos largos (Dynamic Type).
- Al enfocar un campo de texto, el botón principal no puede quedar bajo el teclado: se envía con `onSubmit`
  o se recoge el contenido de encima.
- No uses `.interactive()` en el cristal de una etiqueta de `Menu`: se queda los toques.

**SwiftUI que da problemas**
- En un `ForEach`, los ids no pueden repetirse dentro del mismo contenedor (p. ej. huecos de calendario
  `0..<lead` y días `0..<30`): usa ids negativos o distintos, o faltarán celdas.
- No cierres un `fullScreenCover` para abrir otro enseguida: cambia el contenido dentro del mismo (`.id(...)`).
- Un `accessibilityIdentifier` en un contenedor tapa los de sus hijos: añade antes `.accessibilityElement(children: .contain)`.
- `Activity` (ActivityKit) no es `Sendable`: búscala por id dentro de `Task.detached`.
- Swift 6 estricto: estado de la app en clases `@Observable @MainActor`; nada mutable global sin aislar.

**Lógica y contenido**
- Todo lo que pueda ir en `<App>Kit` va ahí, con tests en `<App>Tests` (Swift Testing).
- Contenido escrito a mano: sin duplicados, opciones distintas entre sí, sin respuestas ambiguas. Un test lo verifica.
- Aleatoriedad reproducible con semilla (`SplitMix`) cuando todos deben ver lo mismo (retos diarios, planes del día).

**Tests de interfaz**
- Hereda de `UITestCase` (generado): `launch`, `waitFor`, `tap`, `enter(…, submit: true)`, `snapshot`.
- Flags de test: `-uiTesting` (datos limpios en memoria) y otros propios (`-seedHistory`, `-revealAnswers`…)
  para sembrar datos de capturas o marcar respuestas. Nunca afectan a un arranque normal.
- La barra de búsqueda flotante de iOS 26 puede tapar elementos: ábrelos por búsqueda o desplázate.
- Cierra las hojas con su botón (con identificador), no con gestos.
- `snapshot` espera medio segundo para no capturar transiciones a medias.
- La CI repite una vez un test de interfaz que falla (`-retry-tests-on-failure`): un fallo que se repite es un error real.
- No metas llamadas que modifican estado dentro de `#expect`.

**Android (Compose)**
- El texto fuera de un `Surface` usa `LocalContentColor`: en temas oscuros proporciónalo en blanco (el tema generado
  ya lo hace) o saldrá negro sobre fondo oscuro.
- Etiquetas de test con `Modifier.testTag("pantalla.cosa")` y `useUnmergedTree = true` al buscarlas.
- Avanza el reloj de Compose (`mainClock.advanceTimeBy`) antes de cada captura para que las animaciones terminen.

**Entrega**
- IPA sin firmar desde la CI (se instala con Sideloadly/AltStore). Un widget no puede leer los datos de la app
  sin App Group (que la instalación con Apple ID gratuito no conserva): diseña widgets que no dependan de ello
  o dilo claramente.
- Sé honesto en el resumen: qué se ha probado (CI, simulador) y qué no (iPhone real).
