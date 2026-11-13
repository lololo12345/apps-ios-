import AVKit
import SwiftData
import SwiftUI

struct TakeReviewView: View {
    let take: Take
    let isFreshRecording: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var saveState: SaveState = .idle
    @State private var confirmDelete = false

    private enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                if TakeStorage.exists(take.fileName) {
                    content
                } else {
                    ContentUnavailableView {
                        Label("Toma no disponible", systemImage: "video.slash")
                    } description: {
                        Text("El archivo de vídeo ya no está en este iPhone.")
                    } actions: {
                        Button("Quitar de la lista", role: .destructive) { delete() }
                            .buttonStyle(.glass)
                    }
                }
            }
            .navigationTitle(isFreshRecording ? "Nueva toma" : "Toma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .accessibilityIdentifier("take.done")
                }
            }
            .confirmationDialog("¿Eliminar esta toma?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar toma", role: .destructive) { delete() }
            } message: {
                Text(take.savedToPhotos ? "La copia guardada en Fotos se mantiene." : "No se ha guardado en Fotos. Se perderá definitivamente.")
            }
        }
        .onAppear {
            guard player == nil, TakeStorage.exists(take.fileName) else { return }
            let player = AVPlayer(url: take.fileURL)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }

    private var content: some View {
        VStack(spacing: 18) {
            VideoPlayer(player: player)
                .aspectRatio(9 / 16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.hairline)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)

            HStack(spacing: 14) {
                Label(ScriptMetrics.clock(take.durationSeconds), systemImage: "timer")
                Text(take.createdAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary)
                if let title = take.story?.displayTitle {
                    Text(title).lineLimit(1).foregroundStyle(.secondary)
                }
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, Metrics.gutter)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Palette.crimson)
                    .accessibilityLabel("Eliminar toma")

                    ShareLink(item: take.fileURL) {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)

                    Button {
                        saveToPhotos()
                    } label: {
                        Group {
                            switch saveState {
                            case .idle, .failed:
                                Label(take.savedToPhotos ? "Guardada" : "Guardar", systemImage: take.savedToPhotos ? "checkmark" : "photo.badge.arrow.down")
                            case .saving:
                                ProgressView()
                            case .saved:
                                Label("Guardada", systemImage: "checkmark")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.ember)
                    .disabled(saveState == .saving || take.savedToPhotos)
                    .accessibilityIdentifier("take.save")
                }
            }
            .padding(.horizontal, Metrics.gutter)

            if case .failed(let message) = saveState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.crimson)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Metrics.gutter)
            }
        }
        .padding(.bottom, 12)
        .animation(.smooth(duration: 0.25), value: saveState)
    }

    private func saveToPhotos() {
        saveState = .saving
        Task {
            do {
                try await PhotoLibrarySaver.saveVideo(at: take.fileURL)
                take.savedToPhotos = true
                try? context.save()
                saveState = .saved
                Haptics.success()
            } catch {
                saveState = .failed(error.localizedDescription)
                Haptics.warning()
            }
        }
    }

    private func delete() {
        player?.pause()
        let take = take
        let context = context
        dismiss()
        // Delete once the sheet is gone so no view renders a deleted model.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            StoryActions.delete(take, in: context)
        }
    }
}
