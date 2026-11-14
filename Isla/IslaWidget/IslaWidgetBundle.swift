import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Action Button: start a quick timer or open Isla with one tap.
struct QuickTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.isla.island.quicktimer") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "isla://start/timer?minutes=5")!)) {
                Label("Temporizador 5 min", systemImage: "timer")
            }
        }
        .displayName("Temporizador rápido")
        .description("Arranca un temporizador de 5 minutos en la isla.")
    }
}

struct FavoritesControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.isla.island.favorites") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "isla://favorites")!)) {
                Label("Isla", systemImage: "capsule.fill")
            }
        }
        .displayName("Favoritos de Isla")
        .description("Abre tus favoritos para lanzarlos al instante.")
    }
}

@main
struct IslaWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslaLiveActivity()
        QuickTimerControl()
        FavoritesControl()
    }
}
