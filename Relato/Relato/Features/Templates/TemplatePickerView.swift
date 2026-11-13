import SwiftData
import SwiftUI

struct TemplatePickerView: View {
    let onCreate: (Story) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.defaultTarget) private var defaultTarget = PrefDefault.defaultTarget
    @State private var target: Int = PrefDefault.defaultTarget

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Duración objetivo")
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(TargetDuration.presets, id: \.self) { seconds in
                                    Button {
                                        target = seconds
                                        Haptics.selection()
                                    } label: {
                                        Chip(title: TargetDuration.label(seconds), symbol: "timer", isSelected: target == seconds)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Estructura")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(StoryTemplate.all) { template in
                                Button {
                                    create(from: template)
                                } label: {
                                    TemplateCard(template: template)
                                }
                                .buttonStyle(PressableCardStyle())
                                .accessibilityIdentifier("template.\(template.id)")
                            }
                        }
                    }
                }
                .padding(Metrics.gutter)
            }
            .background { AuroraBackground(intensity: 0.7) }
            .navigationTitle("Nueva historia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
            }
        }
        .onAppear { target = defaultTarget }
    }

    private func create(from template: StoryTemplate) {
        let story = template.instantiate(in: context, targetSeconds: target)
        try? context.save()
        Haptics.success()
        dismiss()
        onCreate(story)
    }
}

private struct TemplateCard: View {
    let template: StoryTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: template.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(template.genre.tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(template.genre.tint.opacity(0.14)))

            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Text(template.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 4) {
                ForEach(Array(template.beats.enumerated()), id: \.offset) { _, beat in
                    Capsule().fill(beat.kind.tint).frame(height: 5)
                }
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .surfaceCard(padding: 14, radius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Crea una historia con \(template.beats.count) bloques")
    }
}
