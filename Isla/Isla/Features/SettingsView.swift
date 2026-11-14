import ActivityKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                LabeledContent("Actividades en vivo", value: model.liveActivitiesEnabled ? "Activadas" : "Desactivadas")
                Button("Abrir Ajustes del iPhone", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } footer: {
                Text("Isla usa las Actividades en vivo para mostrarse en la Isla Dinámica y en la pantalla de bloqueo. El propio iPhone decide cuántas enseña a la vez.")
            }
            Section("Atajos") {
                Label("«Oye Siri, temporizador en Isla»", systemImage: "waveform")
                Label("«Oye Siri, modo foco en Isla»", systemImage: "waveform")
                Label("En el Centro de Control y el botón de Acción: «Temporizador rápido» y «Favoritos de Isla».", systemImage: "switch.2")
            }
            Section {
                Button("Quitar todo de la isla", role: .destructive) { model.endAll() }
                    .disabled(model.sessions.isEmpty)
            } footer: {
                Text("Todo se guarda solo en este iPhone. La ubicación solo se usa mientras una herramienta de movimiento está activa.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Background())
        .navigationTitle("Ajustes")
    }
}
