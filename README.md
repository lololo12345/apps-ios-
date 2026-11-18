# Apps iOS

Apps nativas para iPhone (SwiftUI · iOS 26 · Liquid Glass) y, cuando se pide, para Android. Cada app vive en su propia carpeta con su
proyecto de Xcode, sus tests y sus capturas. La integración continua (`.github/workflows/ios.yml`)
compila y prueba todas las apps en paralelo en cada push.

| App | Qué es | Carpeta |
|---|---|---|
| **Relato** | Estudio para crear historias de vídeo vertical: guion por bloques, coach de gancho, partes con *cliffhanger* y teleprompter con cámara. | [`Relato/`](Relato/README.md) |
| **Ronda** | Juegos para la previa: 8 juegos en el apartado Normal y 7 en el apartado Hot, con marcador, modo sin alcohol y cartas propias. | [`Ronda/`](Ronda/README.md) |
| **Plan B** | Planes para pareja: 300 ideas con filtros, ruleta, plan sorpresa, diario de citas y widget. | [`PlanB/`](PlanB/README.md) |
| **Isla** | 30 herramientas para la Isla Dinámica: temporizadores, foco, marcador, parada de bus, lista de la compra… | [`Isla/`](Isla/README.md) |
| **Chispa** | El reto diario: cinco retos nuevos cada día (acertijo, cultura, cálculo, memoria y lógica), rachas con protectores y liga con amigos. | [`Chispa/`](Chispa/README.md) |
| **Ronda (Android)** | La misma app para Android (Kotlin · Jetpack Compose), con el mismo contenido y los mismos juegos. | [`RondaAndroid/`](RondaAndroid/README.md) |

## Abrir una app
1. Abre `<App>/<App>.xcodeproj` con Xcode 26 o posterior.
2. En *Signing & Capabilities* elige tu equipo y cambia el *Bundle Identifier* por uno tuyo.
3. Elige un simulador o tu iPhone y pulsa ⌘R.

## Crear una app nueva
```bash
python3 tools/new_ios_app.py <Nombre> <bundle.id> --display "Nombre visible" --summary "Qué es" --kit --widget
```
Para Android: `python3 tools/new_android_app.py <Nombre> <application.id> --display "…" --summary "…"`.

Crea la app completa (proyecto con carpetas sincronizadas, diseño base con Liquid Glass, icono provisional,
ajustes, tests de lógica e interfaz con capturas, README) y la añade a esta tabla. La CI la detecta sola.

## Herramientas
| Herramienta | Para qué |
|---|---|
| `tools/new_ios_app.py` | Crear una app de iPhone nueva lista para trabajar. |
| `tools/new_android_app.py` | Crear una app de Android nueva (Kotlin + Compose) lista para trabajar. |
| `tools/make_xcodeproj.py` | Generar o regenerar solo el proyecto de Xcode (`--shared`, `--widget`). |
| `tools/make_icon.py` | Icono provisional con degradado y letra. |
| `tools/check_swift.sh` | Compilar la lógica (`<App>Kit`) en Linux en segundos, sin Mac. |
| `tools/contact_sheet.py` | Juntar capturas en una sola imagen y avisar de capturas vacías o repetidas. |
| `tools/ci_plan.py` | Decide qué apps compila la CI según lo que haya cambiado. |
