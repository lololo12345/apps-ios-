# Instrucciones para Claude

## Antes de crear una app nueva
0. Ofrece siempre 5 ideas de apps distintas, cada una en una o dos líneas, para que el usuario elija.
1. Cuando elija una, presenta la propuesta de forma breve: problema que resuelve y para quién, funcionalidades,
   pantallas, tecnologías y qué queda fuera del alcance.
2. Espera a que el usuario la acepte explícitamente. Si pide cambios, ajusta la propuesta y vuelve a presentarla.
3. Solo después de la aceptación, empieza a desarrollar.

## Plataformas
- Cada app nueva se hace SIEMPRE para iPhone y para Android, con las mismas funciones y el mismo contenido.
  - iPhone: SwiftUI, carpeta `<App>/` (proyecto con `tools/make_xcodeproj.py`, CI en `ios.yml`).
  - Android: Kotlin + Jetpack Compose, carpeta `<App>Android/` (mismo esquema que `RondaAndroid/`, CI en `android.yml`).
- La propuesta debe indicar las dos versiones y las diferencias inevitables entre plataformas.
- Al terminar, entrega el `.ipa` y el `.apk`.

## Repositorio
- Todo el trabajo de apps (iPhone y Android) va en este repositorio (`lololo12345/apps-ios-`).
- No uses el repositorio `Historias-Tiktok`: es para otra cosa.
