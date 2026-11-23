import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query private var trips: [Trip]
    @State private var confirmClean = false
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Avisos", subtitle: "La víspera del viaje te recuerdo lo que te falta.")
                            GlassRow(title: "Recordatorio", systemImage: "bell.badge.fill") {
                                Toggle("Recordatorio", isOn: $model.remindersOn)
                                    .labelsHidden()
                                    .accessibilityIdentifier("remindersToggle")
                            }
                            if model.remindersOn {
                                GlassRow(title: "Hora", systemImage: "clock.fill") {
                                    Picker("Hora", selection: $model.reminderHour) {
                                        ForEach(8...23, id: \.self) { hour in
                                            Text(String(format: "%02d:00", hour)).tag(hour)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Preferencias")
                            GlassRow(title: "Vibración", systemImage: "iphone.radiowaves.left.and.right") {
                                Toggle("Vibración", isOn: $model.hapticsOn)
                                    .labelsHidden()
                                    .accessibilityIdentifier("hapticsToggle")
                            }
                        }
                        .card()

                        let finished = trips.filter(\.isOver)
                        Button {
                            confirmClean = true
                        } label: {
                            Label("Borrar viajes terminados (\(finished.count))", systemImage: "archivebox")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .disabled(finished.isEmpty)

                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            Label("Restablecer ajustes", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)

                        Text("Mochila · versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"). Todo se guarda solo en este iPhone, sin cuentas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
                .animation(.smooth, value: model.remindersOn)
            }
            .screenBackground()
            .navigationTitle("Ajustes")
            .confirmationDialog("¿Borrar los viajes que ya pasaron?", isPresented: $confirmClean, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    for trip in trips where trip.isOver { context.delete(trip) }
                    try? context.save()
                }
            }
            .confirmationDialog("¿Restablecer los ajustes?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Restablecer", role: .destructive) { model.reset() }
            }
        }
    }
}
