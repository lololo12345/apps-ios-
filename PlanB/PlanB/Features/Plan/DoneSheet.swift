import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// "¡Lo hemos hecho!": date, hearts, a note and a photo for the diary.
struct DoneSheet: View {
    let plan: Plan
    var onSaved: (() -> Void)?

    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var rating = 0
    @State private var note = ""
    @State private var pick: PhotosPickerItem?
    @State private var photo: Data?
    @State private var loadingPhoto = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Text(plan.emoji).font(.largeTitle)
                        Text(plan.title).font(.headline)
                    }
                }
                Section("¿Cuándo?") {
                    DatePicker("Fecha", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                Section("¿Qué tal fue?") {
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                rating = rating == value ? 0 : value
                                Haptics.select()
                            } label: {
                                Image(systemName: value <= rating ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundStyle(value <= rating ? Palette.rose : Color.secondary)
                                    .symbolEffect(.bounce, value: rating == value)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(value) corazones")
                            .accessibilityIdentifier("done.heart.\(value)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    TextField("Una nota para recordarlo…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("done.note")
                }
                Section("Foto") {
                    PhotosPicker(selection: $pick, matching: .images) {
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(.rect(cornerRadius: 16))
                        } else {
                            Label(loadingPhoto ? "Cargando…" : "Añadir una foto", systemImage: "photo.badge.plus")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WarmBackground(colors: plan.colors))
            .navigationTitle("¡Lo habéis hecho!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .accessibilityIdentifier("done.save")
                }
            }
            .onChange(of: pick) { loadPhoto() }
        }
    }

    private func loadPhoto() {
        guard let pick else { return }
        loadingPhoto = true
        Task {
            let data = try? await pick.loadTransferable(type: Data.self)
            photo = data.flatMap(Self.downscaled)
            loadingPhoto = false
        }
    }

    /// Photos are stored at a sensible size (≈1600 px) so the diary stays light.
    static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func save() {
        context.insert(Memory(plan: plan, doneAt: date, rating: rating, note: note.trimmingCharacters(in: .whitespacesAndNewlines), photo: photo))
        try? context.save()
        if state.activePlanID == plan.id { state.clearActive() }
        Haptics.success()
        onSaved?()
        dismiss()
    }
}
