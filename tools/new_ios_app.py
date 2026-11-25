#!/usr/bin/env python3
"""Create a complete, polished iPhone app skeleton that builds and passes its tests from minute one.

    python3 tools/new_ios_app.py <Name> <bundle.id> --display "Nombre" --summary "Qué es en una línea"
        [--accent FFB020] [--background 120C2E] [--glyph N] [--widget] [--kit] [--dark] [--root .]

What you get in <Name>/:
  <Name>.xcodeproj          synchronized folders (new files are picked up automatically), shared scheme
  Config/<Name>-Info.plist  120 Hz, launch colour, URL scheme <name>://
  <Name>/App                @main app, AppModel (@Observable, persisted settings, appearance), LaunchOptions
  <Name>/DesignSystem       Palette, AppBackground, glass cards, hero, badges, rings, stats, chips, empty state
  <Name>/Features           Home + Settings (with Automático / Claro / Oscuro) as a starting point
  (templates: tools/templates/ios, real Swift files with __key__ placeholders)
  <Name>/Resources          AppIcon (generated), AccentColor, LaunchBackground
  <Name>Tests               Swift Testing suite
  <Name>UITests             UITestCase helpers (launch, tap, wait, screenshots) + a first screenshot test
  <Name>Kit (--kit)         plain-Swift logic shared with the widget; checked on Linux by tools/check_swift.sh
  <Name>Widget (--widget)   WidgetKit extension with small and medium widgets
  README.md                 template to fill in with screenshots

CI needs no edit: .github/workflows/ios.yml finds every <Dir>/<Dir>.xcodeproj by itself.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icon import make_icon  # noqa: E402
from make_xcodeproj import make  # noqa: E402


def hex_components(hex_text: str) -> dict:
    value = int(hex_text.lstrip("#"), 16)
    return {"red": f"{((value >> 16) & 0xFF) / 255:.3f}", "green": f"{((value >> 8) & 0xFF) / 255:.3f}",
            "blue": f"{(value & 0xFF) / 255:.3f}", "alpha": "1.000"}


def colorset(hex_text: str) -> str:
    return json.dumps({"colors": [{"color": {"color-space": "srgb", "components": hex_components(hex_text)}, "idiom": "universal"}],
                       "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"


def darken(hex_text: str, factor: float) -> str:
    value = int(hex_text.lstrip("#"), 16)
    parts = [int(((value >> s) & 0xFF) * factor) for s in (16, 8, 0)]
    return "".join(f"{p:02X}" for p in parts)


def lighten(hex_text: str, amount: float) -> str:
    value = int(hex_text.lstrip("#"), 16)
    parts = [(value >> s) & 0xFF for s in (16, 8, 0)]
    return "".join(f"{int(p + (255 - p) * amount):02X}" for p in parts)


def rotate_hue(hex_text: str, turn: float) -> str:
    import colorsys
    value = int(hex_text.lstrip("#"), 16)
    r, g, b = ((value >> s) & 0xFF for s in (16, 8, 0))
    h, l, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    r, g, b = colorsys.hls_to_rgb((h + turn) % 1, l, sat)
    return f"{int(r * 255):02X}{int(g * 255):02X}{int(b * 255):02X}"


def write(path: str, text: str, overwrite: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and not overwrite:
        return
    with open(path, "w") as f:
        f.write(text)


# ---------------------------------------------------------------- templates

TEMPLATES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates", "ios")


def render(template: str, values: dict) -> str:
    """Template file under tools/templates/ios with every `__key__` replaced. The templates are real Swift
    files (no doubled braces), so they can be read and edited like any other source."""
    with open(os.path.join(TEMPLATES, template), encoding="utf-8") as f:
        text = f.read()
    for key, value in values.items():
        text = text.replace(f"__{key}__", str(value))
    left = re.findall(r"__[a-z_]+__", text)
    if left:
        raise SystemExit(f"{template}: faltan valores para {sorted(set(left))}")
    return text


def scaffold(args) -> str:
    root = os.path.abspath(args.root)
    name = args.name
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]+", name):
        raise SystemExit("El nombre debe ser CamelCase sin espacios (p. ej. Chispa, PlanB).")
    app_dir = os.path.join(root, name)
    if os.path.exists(os.path.join(app_dir, f"{name}.xcodeproj")) and not args.force:
        raise SystemExit(f"{name}/ ya existe. Usa --force para regenerar solo lo que falte.")
    scheme = re.sub(r"[^a-z0-9]", "", name.lower())
    display = args.display or name
    summary = args.summary or "Una app nueva."
    shared = f"{name}Kit" if args.kit else None
    make(app_dir, name, args.bundle_id, display, {}, f"Config/{name}-Info.plist", shared, args.widget)

    fmt = dict(name=name, bundle=args.bundle_id, scheme=scheme, display=display.replace('"', '\\"'),
               summary=summary.replace('"', '\\"'), accent=args.accent.upper(), background=args.background.upper(),
               accent_soft=lighten(args.accent, 0.35), background_deep=darken(args.background, 0.55),
               secondary=rotate_hue(args.accent, 0.5),
               # Light mode: a soft wash of the brand colours instead of plain grey, so the glass has colour to refract.
               light_top=lighten(args.accent, 0.88), light_bottom=lighten(rotate_hue(args.accent, 0.5), 0.92),
               default_appearance="dark" if args.dark else "system")
    src = os.path.join(app_dir, name)
    write(os.path.join(app_dir, "Config", f"{name}-Info.plist"), render("Config/Info.plist", fmt))
    write(os.path.join(src, "App", f"{name}App.swift"), render("App/App.swift", fmt))
    write(os.path.join(src, "App", "AppModel.swift"), render("App/AppModel.swift", fmt))
    write(os.path.join(src, "App", "LaunchOptions.swift"), render("App/LaunchOptions.swift", fmt))
    write(os.path.join(src, "DesignSystem", "Theme.swift"), render("DesignSystem/Theme.swift", fmt))
    write(os.path.join(src, "Features", "Home", "HomeView.swift"), render("Features/HomeView.swift", fmt))
    write(os.path.join(src, "Features", "Settings", "SettingsView.swift"), render("Features/SettingsView.swift", fmt))
    write(os.path.join(app_dir, f"{name}Tests", f"{name}Tests.swift"), render("Tests/Tests.swift", fmt))
    write(os.path.join(app_dir, f"{name}UITests", "UITestCase.swift"), render("UITests/UITestCase.swift", fmt))
    write(os.path.join(app_dir, f"{name}UITests", f"{name}UITests.swift"), render("UITests/UITests.swift", fmt))

    assets = os.path.join(src, "Resources", "Assets.xcassets")
    write(os.path.join(assets, "Contents.json"), '{ "info" : { "author" : "xcode", "version" : 1 } }\n')
    write(os.path.join(assets, "AccentColor.colorset", "Contents.json"), colorset(args.accent))
    write(os.path.join(assets, "LaunchBackground.colorset", "Contents.json"), colorset(args.background))
    write(os.path.join(assets, "AppIcon.appiconset", "Contents.json"),
          '{\n  "images" : [\n    { "filename" : "icon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }\n'
          '  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    icon = os.path.join(assets, "AppIcon.appiconset", "icon.png")
    if not os.path.exists(icon):
        make_icon(icon, lighten(args.background, 0.12), darken(args.background, 0.6), args.glyph or name[0], args.accent)

    if args.kit:
        write(os.path.join(app_dir, shared, f"{name}Info.swift"), render("Kit/Info.swift", fmt))
    if args.widget:
        acc, bg = hex_components(args.accent), hex_components(darken(args.background, 0.8))
        wfmt = dict(fmt, acc_r=acc["red"], acc_g=acc["green"], acc_b=acc["blue"], bg_r=bg["red"], bg_g=bg["green"], bg_b=bg["blue"])
        write(os.path.join(app_dir, f"{name}Widget", f"{name}Widget.swift"), render("Widget/Widget.swift", wfmt))
        wassets = os.path.join(app_dir, f"{name}Widget", "Assets.xcassets")
        write(os.path.join(wassets, "Contents.json"), '{ "info" : { "author" : "xcode", "version" : 1 } }\n')
        write(os.path.join(wassets, "AccentColor.colorset", "Contents.json"), colorset(args.accent))

    write(os.path.join(app_dir, "README.md"), render("README.md", dict(
        fmt, data_note="",
        kit_line=f"\n- `{shared}/`: lógica compartida con el widget." if args.kit else "",
        widget_line=f"\n- `{name}Widget/`: el widget." if args.widget else "")))
    os.makedirs(os.path.join(app_dir, "docs", "screenshots"), exist_ok=True)
    write(os.path.join(app_dir, "docs", "screenshots", ".gitkeep"), "")

    index = os.path.join(root, "README.md")
    if args.register and os.path.exists(index):
        text = open(index).read()
        row = f"| **{display}** | {summary} | [`{name}/`]({name}/README.md) |"
        if f"[`{name}/`]" not in text:
            lines = text.split("\n")
            last_row = max(i for i, line in enumerate(lines) if line.startswith("| **"))
            lines.insert(last_row + 1, row)
            open(index, "w").write("\n".join(lines))
    return app_dir


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("name", help="CamelCase, también nombre de la carpeta (p. ej. Chispa)")
    parser.add_argument("bundle_id", help="p. ej. app.chispa.daily")
    parser.add_argument("--display", help="Nombre visible bajo el icono")
    parser.add_argument("--summary", help="Qué es la app, en una línea (README e índice)")
    parser.add_argument("--accent", default="FFB020", help="Color de acento en hex")
    parser.add_argument("--background", default="120C2E", help="Color de fondo / arranque en hex")
    parser.add_argument("--glyph", help="Letra(s) del icono provisional (por defecto, la inicial)")
    parser.add_argument("--dark", action="store_true",
                        help="Empezar en modo oscuro (el usuario puede cambiarlo en Ajustes → Apariencia)")
    parser.add_argument("--kit", action="store_true", help="Carpeta <Name>Kit con lógica compartida")
    parser.add_argument("--widget", action="store_true", help="Extensión de widget")
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="Raíz del repositorio (por defecto, este)")
    parser.add_argument("--no-register", dest="register", action="store_false", help="No añadir la fila al README raíz")
    parser.add_argument("--force", action="store_true", help="Regenerar el proyecto y crear solo los archivos que falten")
    path = scaffold(parser.parse_args())
    print(f"Lista: {path}\nSiguiente: escribe la lógica en el Kit o en {os.path.basename(path)}/, haz push y revisa las capturas.")
