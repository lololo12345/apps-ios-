import SwiftData
import SwiftUI

/// Capture-first idea vault: write a line before it escapes, turn it into a story later.
struct IdeasView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @AppStorage(PrefKey.defaultTarget) private var defaultTarget = PrefDefault.defaultTarget

    @State private var draft = ""
    @FocusState private var captureFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    captureField
                        .listRowInsets(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 8, trailing: Metrics.gutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if ideas.isEmpty {
                    Section {
                        EmptyStateView(
                            symbol: "lightbulb.max",
                            title: "Tu banco de ideas",
                            message: "Esa anécdota del bar, el titular raro, lo que te contó tu abuela… Apúntalo aquí en segundos y conviértelo en historia cuando quieras."
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(ideas) { idea in
                            IdeaRow(idea: idea)
                                .listRowInsets(EdgeInsets(top: 5, leading: Metrics.gutter, bottom: 5, trailing: Metrics.gutter))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation { context.delete(idea) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        convert(idea)
                                    } label: {
                                        Label("Historia", systemImage: "wand.and.stars")
                                    }
                                    .tint(Palette.ember)
                                }
                                .contextMenu {
                                    Button { convert(idea) } label: {
                                        Label("Convertir en historia", systemImage: "wand.and.stars")
                                    }
                                    ShareLink(item: idea.text) {
                                        Label("Compartir", systemImage: "square.and.arrow.up")
                                    }
                                    Button(role: .destructive) {
                                        withAnimation { context.delete(idea) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        SectionTitle(title: "\(ideas.count) \(ideas.count == 1 ? "idea" : "ideas")", trailing: "Desliza → para convertir")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { AuroraBackground() }
            .navigationTitle("Ideas")
            .animation(.smooth(duration: 0.3), value: ideas.map(\.id))
        }
    }

    private var captureField: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Apunta una idea antes de que se escape…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($captureFocused)
                .submitLabel(.send)
                .onSubmit { save() }
                .padding(.vertical, 12)
                .padding(.leading, 16)
                .accessibilityIdentifier("ideas.capture")

            Button {
                save()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(6)
            .accessibilityLabel("Guardar idea")
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.smooth) { context.insert(Idea(text: text)) }
        draft = ""
        Haptics.success()
    }

    private func convert(_ idea: Idea) {
        let story = StoryActions.makeStory(from: idea, in: context, targetSeconds: defaultTarget)
        Haptics.success()
        router.open(story)
    }
}

private struct IdeaRow: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(idea.text)
                .font(.body)
                .foregroundStyle(.primary)
            Text(idea.createdAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(padding: 16, radius: 20)
    }
}
