#!/usr/bin/env python3
"""Create a complete, polished iPhone app skeleton that builds and passes its tests from minute one.

    python3 tools/new_ios_app.py <Name> <bundle.id> --display "Nombre" --summary "Qué es en una línea"
        [--accent FFB020] [--background 120C2E] [--glyph N] [--widget] [--kit] [--dark] [--root .]

What you get in <Name>/:
  <Name>.xcodeproj          synchronized folders (new files are picked up automatically), shared scheme
  Config/<Name>-Info.plist  120 Hz, launch colour, URL scheme <name>://
  <Name>/App                @main app, AppModel (@Observable, persisted settings), LaunchOptions for UI tests
  <Name>/DesignSystem       Palette, AppBackground, glass cards, buttons, haptics, number formatting
  <Name>/Features           Home + Settings tabs as a starting point
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

INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>{bundle}</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>{scheme}</string>
			</array>
		</dict>
	</array>
	<key>UILaunchScreen</key>
	<dict>
		<key>UIColorName</key>
		<string>LaunchBackground</string>
	</dict>
</dict>
</plist>
"""

APP = """import SwiftUI

@main
struct {name}App: App {{
    @State private var model = AppModel()

    var body: some Scene {{
        WindowGroup {{
            RootView()
                .environment(model){scheme_line}
                .tint(Palette.accent)
        }}
    }}
}}

enum AppTab: Hashable {{
    case home, settings
}}

struct RootView: View {{
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .home

    var body: some View {{
        // Native iOS 26 tab bar: Liquid Glass, drag across it to switch tabs, and it shrinks into a capsule
        // while scrolling (kept full-size under UI tests so every tab stays tappable).
        TabView(selection: $tab) {{
            Tab("Inicio", systemImage: "house.fill", value: AppTab.home) {{ HomeView() }}
            Tab("Ajustes", systemImage: "gearshape.fill", value: AppTab.settings) {{ SettingsView() }}
        }}
        .tabBarMinimizeBehavior(LaunchOptions.isUITesting ? .never : .onScrollDown)
        .sensoryFeedback(.selection, trigger: tab) {{ _, _ in model.hapticsOn }}
        .onOpenURL {{ url in
            // {scheme}://settings opens the settings tab; anything else goes home.
            guard url.scheme == "{scheme}" else {{ return }}
            tab = url.host() == "settings" ? .settings : .home
        }}
    }}
}}
"""

MODEL = """import Foundation
import Observation

/// App-wide state. Settings persist in UserDefaults; UI tests get a fresh, separate store every launch.
@Observable
@MainActor
final class AppModel {{
    private let defaults: UserDefaults

    var hapticsOn: Bool {{ didSet {{ defaults.set(hapticsOn, forKey: Keys.haptics) }} }}
    var launchCount: Int {{ didSet {{ defaults.set(launchCount, forKey: Keys.launches) }} }}

    private enum Keys {{
        static let haptics = "settings.haptics", launches = "app.launches"
    }}

    init(defaults: UserDefaults = LaunchOptions.defaults) {{
        self.defaults = defaults
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        launchCount = defaults.integer(forKey: Keys.launches) + 1
        defaults.set(launchCount, forKey: Keys.launches)
    }}

    func reset() {{
        hapticsOn = true
        launchCount = 1
    }}
}}
"""

LAUNCH_OPTIONS = """import Foundation

/// Flags passed by the UI tests (`app.launchArguments`). Never active in a normal launch.
enum LaunchOptions {{
    static var arguments: [String] {{ ProcessInfo.processInfo.arguments }}
    static var isUITesting: Bool {{ arguments.contains("-uiTesting") }}

    /// `-flag value` pairs, e.g. `-playerName Lola`.
    static func value(after flag: String) -> String? {{
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {{ return nil }}
        return arguments[index + 1]
    }}

    /// Real defaults normally; an empty, throw-away suite under UI tests so every test starts clean.
    static var defaults: UserDefaults {{
        guard isUITesting else {{ return .standard }}
        let suite = "{bundle}.uitests"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }}
}}
"""

THEME = """import SwiftUI

extension Color {{
    init(hex: UInt32, opacity: Double = 1) {{
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }}
}}

enum Palette {{
    static let accent = Color(hex: 0x{accent})
    static let accentSoft = Color(hex: 0x{accent_soft})
    static let background = Color(hex: 0x{background})
    static let backgroundDeep = Color(hex: 0x{background_deep})
    static let good = Color(hex: 0x3DDC97)
    static let bad = Color(hex: 0xFF5A6E)
    /// Complementary hue (accent rotated on the colour wheel) for the third background glow.
    static let secondary = Color(hex: 0x{secondary})
    static let brand: [Color] = [accentSoft, accent]
}}

enum Metrics {{
    /// Side margin of every screen (also the minimum on the smallest iPhone).
    static let gutter: CGFloat = 16
    static let radius: CGFloat = 24
}}

/// Screen background: a vertical gradient plus two soft glows. Radial gradients only (no blur),
/// so scrolling and animations on top stay at 120 Hz.
struct AppBackground: View {{
    var glow: Color = Palette.accent
    @Environment(\\.colorScheme) private var scheme

    var body: some View {{
        GeometryReader {{ proxy in
            let longest = max(proxy.size.width, proxy.size.height)
            ZStack {{
                if scheme == .dark {{
                    LinearGradient(colors: [Palette.background, Palette.backgroundDeep], startPoint: .top, endPoint: .bottom)
                }} else {{
                    Color(uiColor: .systemGroupedBackground)
                }}
                // Colour for the glass to refract: Liquid Glass looks best over soft, saturated light.
                RadialGradient(colors: [glow.opacity(scheme == .dark ? 0.38 : 0.26), .clear], center: UnitPoint(x: 0.95, y: 0.0),
                               startRadius: 0, endRadius: longest * 0.6)
                RadialGradient(colors: [Palette.accentSoft.opacity(scheme == .dark ? 0.24 : 0.18), .clear], center: UnitPoint(x: 0.0, y: 0.55),
                               startRadius: 0, endRadius: longest * 0.55)
                RadialGradient(colors: [Palette.secondary.opacity(scheme == .dark ? 0.22 : 0.14), .clear], center: UnitPoint(x: 0.85, y: 1.0),
                               startRadius: 0, endRadius: longest * 0.55)
            }}
        }}
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }}
}}

extension View {{
    /// Rounded Liquid Glass surface used for every card. Pass a tint to colour it.
    func card(tint: Color? = nil, radius: CGFloat = Metrics.radius) -> some View {{
        let glass: Glass = tint.map {{ Glass.regular.tint($0.opacity(0.22)) }} ?? .regular
        return padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: radius))
    }}

    func brandGradientText() -> some View {{
        foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .leading, endPoint: .trailing))
    }}

    /// Standard screen chrome: background, side margins handled by the content, hidden scroll bars.
    func screenBackground(glow: Color = Palette.accent) -> some View {{
        scrollIndicators(.hidden).background(AppBackground(glow: glow))
    }}
}}

/// Press-down feedback for custom tappable surfaces (cards, tiles).
struct PressableStyle: ButtonStyle {{
    func makeBody(configuration: Configuration) -> some View {{
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }}
}}

/// Big full-width call to action.
struct PrimaryButton: View {{
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {{
        Button(action: action) {{
            Label {{
                Text(title)
            }} icon: {{
                if let systemImage {{ Image(systemName: systemImage) }}
            }}
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }}
        .buttonStyle(.glassProminent)
        .tint(Palette.accent)
    }}
}}

/// Round glass icon button (toolbars, headers). Group several inside a `GlassEffectContainer` so they blend.
struct GlassIconButton: View {{
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {{
        Button(action: action) {{
            Image(systemName: systemImage).font(.headline).frame(width: 24, height: 24)
        }}
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }}
}}

/// One settings row inside a glass card: icon, title and any trailing control.
struct GlassRow<Trailing: View>: View {{
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: Trailing

    var body: some View {{
        HStack(spacing: 12) {{
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(Palette.accent.opacity(0.18)), in: .circle)
            Text(title)
            Spacer(minLength: 8)
            trailing
        }}
        .padding(.vertical, 4)
    }}
}}

/// Title + optional subtitle used at the top of cards.
struct SectionHeader: View {{
    let title: String
    var subtitle: String?

    var body: some View {{
        VStack(alignment: .leading, spacing: 2) {{
            Text(title).font(.system(.headline, design: .rounded, weight: .bold))
            if let subtitle {{ Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }}
        }}
        .frame(maxWidth: .infinity, alignment: .leading)
    }}
}}

extension Int {{
    /// 12.345 (Spanish grouping) for scores and counters.
    var grouped: String {{ formatted(.number.locale(Locale(identifier: "es_ES"))) }}
}}

extension String {{
    /// "domingo, 15 de noviembre" → "Domingo, 15 de noviembre" (`capitalized` would capitalise every word).
    var sentenceCased: String {{ prefix(1).uppercased() + dropFirst() }}
}}
"""

HOME = """import SwiftUI

struct HomeView: View {{
    @Environment(AppModel.self) private var model
    @State private var taps = 0

    var body: some View {{
        NavigationStack {{
            ScrollView {{
                VStack(alignment: .leading, spacing: 16) {{
                    VStack(alignment: .leading, spacing: 8) {{
                        Text("{display}")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .brandGradientText()
                        Text("{summary}")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }}
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {{
                        SectionHeader(title: "Empieza aquí", subtitle: "Sustituye esta pantalla por la primera de la app.")
                        Text("Pulsaciones: \\(taps.grouped)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("tapCount")
                        PrimaryButton(title: "Pulsar", systemImage: "hand.tap.fill") {{
                            withAnimation(.snappy) {{ taps += 1 }}
                        }}
                        .accessibilityIdentifier("tapButton")
                    }}
                    .card()
                    .accessibilityElement(children: .contain)
                }}
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }}
            .screenBackground()
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .light), trigger: taps) {{ _, _ in model.hapticsOn }}
        }}
    }}
}}
"""

SETTINGS = """import SwiftUI

struct SettingsView: View {{
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {{
        @Bindable var model = model
        NavigationStack {{
            ScrollView {{
                GlassEffectContainer(spacing: 16) {{
                    VStack(alignment: .leading, spacing: 16) {{
                        VStack(alignment: .leading, spacing: 8) {{
                            SectionHeader(title: "Preferencias")
                            GlassRow(title: "Vibración", systemImage: "iphone.radiowaves.left.and.right") {{
                                Toggle("Vibración", isOn: $model.hapticsOn)
                                    .labelsHidden()
                                    .accessibilityIdentifier("hapticsToggle")
                            }}
                        }}
                        .card()

                        Button(role: .destructive) {{
                            confirmReset = true
                        }} label: {{
                            Label("Restablecer ajustes", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }}
                        .buttonStyle(.glass)

                        Text("{display} · versión \\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"). Todo se guarda solo en este iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }}
                }}
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }}
            .screenBackground()
            .navigationTitle("Ajustes")
            .confirmationDialog("¿Restablecer los ajustes?", isPresented: $confirmReset, titleVisibility: .visible) {{
                Button("Restablecer", role: .destructive) {{ model.reset() }}
            }}
        }}
    }}
}}
"""

UNIT_TESTS = """import Foundation
import Testing
@testable import {name}

@Suite("App")
@MainActor
struct AppModelTests {{
    private func makeModel() -> AppModel {{
        AppModel(defaults: UserDefaults(suiteName: "{name}.tests.\\(UUID().uuidString)")!)
    }}

    @Test func startsWithSensibleDefaults() {{
        let model = makeModel()
        #expect(model.hapticsOn)
        #expect(model.launchCount == 1)
    }}

    @Test func resetRestoresDefaults() {{
        let model = makeModel()
        model.hapticsOn = false
        model.reset()
        #expect(model.hapticsOn)
    }}

    @Test func formatting() {{
        #expect(12345.grouped == "12.345")
        #expect("domingo, 15 de noviembre".sentenceCased == "Domingo, 15 de noviembre")
    }}
}}
"""

UI_HELPERS = """import XCTest

/// Base class for UI tests: launch with test flags, find by identifier, tap, wait and take screenshots.
/// Screenshots named "01-something" are exported by CI (artifact screenshots-<App>), sorted by name.
class UITestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    @MainActor
    func snapshot(_ name: String, _ app: XCUIApplication, settle: TimeInterval = 0.5) {
        // Let transitions finish so the screenshot never catches a half-drawn screen.
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    @discardableResult
    func waitFor(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: timeout), "Missing \\(id)")
        return item
    }

    @MainActor
    func tap(_ id: String, _ app: XCUIApplication, timeout: TimeInterval = 6) {
        waitFor(id, app, timeout: timeout).tap()
    }

    @MainActor
    func enter(_ text: String, into id: String, _ app: XCUIApplication, submit: Bool = false) {
        let field = waitFor(id, app)
        field.tap()
        // "\\n" submits through the keyboard: buttons under the keyboard cannot be tapped.
        field.typeText(submit ? text + "\\n" : text)
    }

    @MainActor
    func tab(_ name: String, _ app: XCUIApplication) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \\(name)")
        button.tap()
    }

    @MainActor
    func text(containing fragment: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    @MainActor
    func wait(until predicate: String, on item: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: item)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitToDisappear(_ item: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        wait(until: "exists == false", on: item, timeout: timeout)
    }
}
"""

UI_TESTS = """import XCTest

final class {name}UITests: UITestCase {{
    @MainActor
    func testHomeAndSettings() {{
        let app = launch()
        waitFor("tapButton", app)
        snapshot("01-home", app)
        tap("tapButton", app)
        XCTAssertTrue(wait(until: "label CONTAINS '1'", on: element("tapCount", app)))

        tab("Ajustes", app)
        waitFor("hapticsToggle", app)
        snapshot("02-settings", app)
    }}
}}
"""

KIT = """import Foundation

/// Plain-Swift logic (no SwiftUI/UIKit) shared by the app and the widget.
/// Keep it Foundation-only so `tools/check_swift.sh {name}` can type-check it on Linux in seconds.
enum {name}Info {{
    static let name = "{display}"
    static let urlScheme = "{scheme}"
}}
"""

WIDGET = """import SwiftUI
import WidgetKit

struct {name}Entry: TimelineEntry {{
    let date: Date
}}

struct {name}Provider: TimelineProvider {{
    func placeholder(in context: Context) -> {name}Entry {{ {name}Entry(date: .now) }}

    func getSnapshot(in context: Context, completion: @escaping ({name}Entry) -> Void) {{
        completion({name}Entry(date: .now))
    }}

    func getTimeline(in context: Context, completion: @escaping (Timeline<{name}Entry>) -> Void) {{
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [{name}Entry(date: .now)], policy: .after(tomorrow)))
    }}
}}

struct {name}WidgetView: View {{
    let entry: {name}Entry
    @Environment(\\.widgetFamily) private var family

    var body: some View {{
        VStack(alignment: .leading, spacing: 6) {{
            Text("{display}")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(entry.date, format: .dateTime.weekday(.wide).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }}
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {{
            LinearGradient(colors: [Color(red: {acc_r}, green: {acc_g}, blue: {acc_b}), Color(red: {bg_r}, green: {bg_g}, blue: {bg_b})],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }}
        .widgetURL(URL(string: "{scheme}://home"))
    }}
}}

struct {name}Widget: Widget {{
    var body: some WidgetConfiguration {{
        StaticConfiguration(kind: "{bundle}.widget.main", provider: {name}Provider()) {{ entry in
            {name}WidgetView(entry: entry)
        }}
        .configurationDisplayName("{display}")
        .description("{summary}")
        .supportedFamilies([.systemSmall, .systemMedium])
    }}
}}

@main
struct {name}WidgetBundle: WidgetBundle {{
    var body: some Widget {{
        {name}Widget()
    }}
}}
"""

README = """# {display}

{summary}

| Inicio | Ajustes |
|---|---|
| ![](docs/screenshots/01-home.jpg) | ![](docs/screenshots/02-settings.jpg) |

## Qué incluye
- (Funciones, en una línea cada una.)

## Proyecto
- `{name}/`: la app (SwiftUI, Liquid Glass{data_note}).{kit_line}{widget_line}
- Tests: lógica con Swift Testing y recorridos por la interfaz con capturas.

Todo se guarda solo en el iPhone.
"""


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
               scheme_line="\n                .preferredColorScheme(.dark)" if args.dark else "")
    src = os.path.join(app_dir, name)
    write(os.path.join(app_dir, "Config", f"{name}-Info.plist"), INFO_PLIST.format(**fmt))
    write(os.path.join(src, "App", f"{name}App.swift"), APP.format(**fmt))
    write(os.path.join(src, "App", "AppModel.swift"), MODEL.format(**fmt))
    write(os.path.join(src, "App", "LaunchOptions.swift"), LAUNCH_OPTIONS.format(**fmt))
    write(os.path.join(src, "DesignSystem", "Theme.swift"), THEME.format(**fmt))
    write(os.path.join(src, "Features", "Home", "HomeView.swift"), HOME.format(**fmt))
    write(os.path.join(src, "Features", "Settings", "SettingsView.swift"), SETTINGS.format(**fmt))
    write(os.path.join(app_dir, f"{name}Tests", f"{name}Tests.swift"), UNIT_TESTS.format(**fmt))
    write(os.path.join(app_dir, f"{name}UITests", "UITestCase.swift"), UI_HELPERS)
    write(os.path.join(app_dir, f"{name}UITests", f"{name}UITests.swift"), UI_TESTS.format(**fmt))

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
        write(os.path.join(app_dir, shared, f"{name}Info.swift"), KIT.format(**fmt))
    if args.widget:
        acc, bg = hex_components(args.accent), hex_components(darken(args.background, 0.8))
        wfmt = dict(fmt, acc_r=acc["red"], acc_g=acc["green"], acc_b=acc["blue"], bg_r=bg["red"], bg_g=bg["green"], bg_b=bg["blue"])
        write(os.path.join(app_dir, f"{name}Widget", f"{name}Widget.swift"), WIDGET.format(**wfmt))
        wassets = os.path.join(app_dir, f"{name}Widget", "Assets.xcassets")
        write(os.path.join(wassets, "Contents.json"), '{ "info" : { "author" : "xcode", "version" : 1 } }\n')
        write(os.path.join(wassets, "AccentColor.colorset", "Contents.json"), colorset(args.accent))

    write(os.path.join(app_dir, "README.md"), README.format(
        **fmt, data_note="",
        kit_line=f"\n- `{shared}/`: lógica compartida con el widget." if args.kit else "",
        widget_line=f"\n- `{name}Widget/`: el widget." if args.widget else ""))
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
    parser.add_argument("--dark", action="store_true", help="Forzar modo oscuro (apps de diseño nocturno)")
    parser.add_argument("--kit", action="store_true", help="Carpeta <Name>Kit con lógica compartida")
    parser.add_argument("--widget", action="store_true", help="Extensión de widget")
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="Raíz del repositorio (por defecto, este)")
    parser.add_argument("--no-register", dest="register", action="store_false", help="No añadir la fila al README raíz")
    parser.add_argument("--force", action="store_true", help="Regenerar el proyecto y crear solo los archivos que falten")
    path = scaffold(parser.parse_args())
    print(f"Lista: {path}\nSiguiente: escribe la lógica en el Kit o en {os.path.basename(path)}/, haz push y revisa las capturas.")
