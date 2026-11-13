# Apps iOS

Apps nativas para iPhone (SwiftUI · iOS 26 · Liquid Glass). Cada app vive en su propia carpeta con su
proyecto de Xcode, sus tests y sus capturas. La integración continua (`.github/workflows/ios.yml`)
compila y prueba todas las apps en paralelo en cada push.

| App | Qué es | Carpeta |
|---|---|---|
| **Relato** | Estudio para crear historias de vídeo vertical: guion por bloques, coach de gancho, partes con *cliffhanger* y teleprompter con cámara. | [`Relato/`](Relato/README.md) |
| **Ronda** | Juegos para la previa: 8 juegos en el apartado Normal y 7 en el apartado Hot, con marcador, modo sin alcohol y cartas propias. | [`Ronda/`](Ronda/README.md) |

## Abrir una app
1. Abre `<App>/<App>.xcodeproj` con Xcode 26 o posterior.
2. En *Signing & Capabilities* elige tu equipo y cambia el *Bundle Identifier* por uno tuyo.
3. Elige un simulador o tu iPhone y pulsa ⌘R.

## Crear una app nueva
```bash
python3 tools/make_xcodeproj.py <Carpeta> <Nombre> <bundle.id> --display "Nombre visible"
```
Genera el proyecto con carpetas sincronizadas (cualquier archivo nuevo se incluye solo), targets de tests
unitarios y de interfaz y un esquema compartido. Después añade el nombre a la matriz de `ios.yml`.
