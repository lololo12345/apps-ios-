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
- iPhone: SwiftUI, carpeta `<App>/` (proyecto con `tools/make_xcodeproj.py`, CI en `ios.yml`). Se entrega el `.ipa`.
- Android: Kotlin + Jetpack Compose, carpeta `<App>Android/` (mismo esquema que `RondaAndroid/`, CI en
  `android.yml`). Se entrega el `.apk`.
- Si más adelante pide la otra plataforma de una app ya hecha, pórtala con las mismas funciones y contenido.

## Repositorio
- Todo el trabajo de apps (iPhone y Android) va en este repositorio (`lololo12345/apps-ios-`).
- No uses el repositorio `Historias-Tiktok`: es para otra cosa.
