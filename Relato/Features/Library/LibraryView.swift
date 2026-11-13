import SwiftData
import SwiftUI

struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all, draft, ready, recorded, published
        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Todas"
            case .draft: "Borradores"
            case .ready: "Listas"
            case .recorded: "Grabadas"
            case .published: "Publicadas"
            }
        }

        var status: StoryStatus? {
            switch self {
            case .all: nil
            case .draft: .draft
            case .ready: .ready
            case .recorded: .recorded
            case .published: .published
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Story.updatedAt, order: .reverse) private var stories: [Story]
    @Query(sort: \Take.createdAt, order: .reverse) private var takes: [Take]
    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute

    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showingTemplates = false
    @State private var storyPendingDeletion: Story?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.storyPath) {
            Group {
                if stories.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            symbol: "book.pages",
                            title: "Tu primera historia empieza aquí",
                            message: "Elige una estructura probada y escribe bloque a bloque. Relato calcula el tiempo y puntúa tu gancho.",
                            actionTitle: "Crear historia",
                            action: { showingTemplates = true },
                            secondaryTitle: "Ver historias de ejemplo",
                            secondaryAction: { SampleContent.insert(into: context) }
                        )
                        .padding(.top, 40)
                    }
                } else {
                    list
                }
            }
            .background { AuroraBackground() }
            .navigationTitle("Historias")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showingTemplates = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nueva historia")
                    .accessibilityIdentifier("library.new")
                }
            }
            .navigationDestination(for: Story.self) { story in
                StoryEditorView(story: story)
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatePickerView { story in
                    router.storyPath.append(story)
                }
            }
            .confirmationDialog(
                "¿Eliminar «\(storyPendingDeletion?.displayTitle ?? "")»?",
                isPresented: Binding(get: { storyPendingDeletion != nil }, set: { if !$0 { storyPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Eliminar historia y tomas", role: .destructive) {
                    if let story = storyPendingDeletion {
                        withAnimation { StoryActions.delete(story, in: context) }
                        Haptics.warning()
                    }
                    storyPendingDeletion = nil
                }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
    }

    // MARK: - List

    private var filteredStories: [Story] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return stories.filter { story in
            if let status = filter.status, story.status != status { return false }
            guard !query.isEmpty else { return true }
            if story.title.localizedStandardContains(query) { return true }
            return (story.beats ?? []).contains { $0.text.localizedStandardContains(query) }
        }
        .sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var list: some View {
        let visible = filteredStories
        return List {
            Section {
                statsHeader
                    .listRowInsets(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 8, trailing: Metrics.gutter))
                filterBar
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if visible.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Nada en «\(filter.title)»" : "Sin resultados",
                        systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Cuando una historia llegue a este estado aparecerá aquí." : "Prueba con otra palabra del título o del guion.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(visible) { story in
                        Button {
                            router.storyPath.append(story)
                        } label: {
                            StoryCard(story: story, wordsPerMinute: wordsPerMinute)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityIdentifier("story.\(story.displayTitle)")
                        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                storyPendingDeletion = story
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                story.isPinned.toggle()
                                Haptics.tap()
                            } label: {
                                Label(story.isPinned ? "Desfijar" : "Fijar", systemImage: story.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(Palette.amber)
                        }
                        .contextMenu { contextMenu(for: story) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Buscar en tus historias")
        .animation(.smooth(duration: 0.3), value: filter)
        .animation(.smooth(duration: 0.3), value: visible.map(\.id))
    }

    @ViewBuilder
    private func contextMenu(for story: Story) -> some View {
        Button {
            story.isPinned.toggle()
        } label: {
            Label(story.isPinned ? "Desfijar" : "Fijar arriba", systemImage: story.isPinned ? "pin.slash" : "pin")
        }
        Button {
            let copy = StoryActions.duplicate(story, in: context)
            router.storyPath.append(copy)
        } label: {
            Label("Duplicar", systemImage: "plus.square.on.square")
        }
        Menu {
            ForEach(StoryStatus.allCases) { status in
                Button {
                    story.status = status
                    story.touch()
                } label: {
                    Label(status.title, systemImage: status.symbol)
                }
            }
        } label: {
            Label("Cambiar estado", systemImage: "flag")
        }
        Divider()
        Button(role: .destructive) {
            storyPendingDeletion = story
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }

    // MARK: - Header

    private var statsHeader: some View {
        let takeDates = takes.map(\.createdAt)
        let streak = StreakCalculator.currentStreak(activityDates: takeDates)
        let weekTakes = StreakCalculator.count(activityDates: takeDates, inLastDays: 7)
        return HStack(spacing: 10) {
            StatTile(value: "\(stories.count)", label: "Historias", symbol: "book.pages.fill", tint: Palette.violet)
            StatTile(value: "\(stories.filter { $0.status == .ready }.count)", label: "Para grabar", symbol: "checkmark.seal.fill", tint: Palette.mint)
            StatTile(
                value: streak > 0 ? "\(streak) d" : "\(weekTakes)",
                label: streak > 0 ? "Racha" : "Tomas 7 días",
                symbol: streak > 0 ? "flame.fill" : "video.fill",
                tint: Palette.ember
            )
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    let count = item.status.map { status in stories.filter { $0.status == status }.count } ?? stories.count
                    Button {
                        filter = item
                        Haptics.selection()
                    } label: {
                        Chip(title: item.title, tint: Palette.ember, isSelected: filter == item, count: count)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Story card

struct StoryCard: View {
    let story: Story
    let wordsPerMinute: Double

    var body: some View {
        let segments = story.segments
        let total = ScriptMetrics.spokenSeconds(segments, wordsPerMinute: wordsPerMinute)
        let target = Double(story.targetSeconds)
        let hook = story.hookText.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Tag(title: story.genre.title, symbol: story.genre.symbol, tint: story.genre.tint)
                if story.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Palette.amber)
                        .accessibilityLabel("Fijada")
                }
                Spacer()
                Label(story.status.title, systemImage: story.status.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(story.status.tint)
            }

            Text(story.displayTitle)
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if !hook.isEmpty {
                Text("“\(hook)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                TimingBar(
                    slices: segments.map { .init(id: $0.id, seconds: ScriptMetrics.spokenSeconds($0.text, wordsPerMinute: wordsPerMinute), tint: $0.kind.tint) },
                    targetSeconds: target,
                    height: 6
                )
                HStack {
                    Text("\(ScriptMetrics.clock(total)) / \(ScriptMetrics.clock(target))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(total > target ? Palette.crimson : .secondary)
                    Spacer()
                    let takeCount = story.takes?.count ?? 0
                    if takeCount > 0 {
                        Label("\(takeCount)", systemImage: "video")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(takeCount) tomas")
                    }
                    Text(story.updatedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
