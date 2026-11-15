import SwiftUI

struct LeagueView: View {
    @Environment(GameStore.self) private var store
    @State private var showAdd = false
    @State private var importMessage: String?

    private let dayLetters = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    weekHeader
                    table
                    shareCard
                    if !store.waitingFriends.isEmpty { waiting }
                    howItWorks
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(NightBackground(glow: Color(hex: 0x6E4BFF)))
            .navigationTitle("Liga de amigos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Añadir amigo", systemImage: "person.badge.plus") { showAdd = true }
                        .accessibilityIdentifier("addFriend")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddFriendSheet { name in
                    importMessage = "\(name) está en tu liga."
                }
                .presentationDetents([.medium, .large])
            }
            .overlay(alignment: .bottom) {
                if let importMessage {
                    Text(importMessage)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .glassEffect(.regular.tint(Palette.good.opacity(0.3)), in: .capsule)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { self.importMessage = nil }
                        }
                }
            }
            .animation(.smooth, value: importMessage)
        }
    }

    private var weekHeader: some View {
        let end = store.today.weekStart.adding(7).startDate()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Semana del \(store.today.weekStart.formatted(.dateTime.day().month(.wide)))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.muted)
            CountdownLabel(target: end, prefix: "La liga termina en")
        }
    }

    private var table: some View {
        VStack(spacing: 10) {
            ForEach(Array(store.leagueRows.enumerated()), id: \.element.id) { position, row in
                LeagueRowView(position: position + 1, row: row, dayLetters: dayLetters, todayIndex: store.today.weekdayIndex,
                              hasRivals: store.leagueRows.count > 1)
                    .contextMenu {
                        if !row.isMe, let friend = store.friends.first(where: { $0.playerID == row.id }) {
                            Button("Quitar de la liga", systemImage: "trash", role: .destructive) { store.remove(friend) }
                        }
                    }
            }
            if store.leagueRows.count == 1 {
                Text("Aún no hay nadie más en tu liga esta semana. Comparte tu código y pega el de tus amigos.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leagueTable")
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tu código de esta semana", systemImage: "qrcode")
                .font(.headline)
            Text("Lleva tus puntos de la semana y tu resultado de hoy. Envíalo cada vez que juegues para que tus amigos te vean al día.")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            ShareLink(item: store.shareMessage) {
                Label("Enviar a mis amigos", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.ember)
            .accessibilityIdentifier("shareCode")
        }
        .card(tint: Palette.ember)
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Esperando su código de esta semana").font(.headline)
            ForEach(store.waitingFriends, id: \.playerID) { friend in
                HStack {
                    Image(systemName: "hourglass").foregroundStyle(Palette.muted)
                    Text(friend.name)
                    Spacer()
                    Button(role: .destructive) { store.remove(friend) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        }
        .card()
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cómo funciona").font(.headline)
            Label("La liga va de lunes a domingo y suma los puntos de cada día.", systemImage: "calendar")
            Label("Compartes tu código por WhatsApp, Telegram o donde quieras.", systemImage: "square.and.arrow.up")
            Label("Tu amigo lo pega en «Añadir amigo» y apareces en su tabla (y al revés).", systemImage: "doc.on.clipboard")
            Label("Los códigos van firmados: si alguien cambia los puntos, la app lo rechaza.", systemImage: "checkmark.shield.fill")
        }
        .font(.footnote)
        .foregroundStyle(Palette.muted)
    }
}

struct LeagueRowView: View {
    let position: Int
    let row: LeagueRow
    let dayLetters: [String]
    let todayIndex: Int
    let hasRivals: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(medal.opacity(0.9)).frame(width: 34, height: 34)
                    if position == 1 && hasRivals {
                        Image(systemName: "crown.fill").font(.subheadline).foregroundStyle(Color(hex: 0x3A2500))
                    } else {
                        Text("\(position)").font(.headline.weight(.heavy)).foregroundStyle(position <= 3 ? Color(hex: 0x2A1300) : .white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.isMe ? "\(row.name) (tú)" : row.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    HStack(spacing: 6) {
                        if row.streak > 0 {
                            Label("\(row.streak)", systemImage: "flame.fill").labelStyle(.titleAndIcon)
                        }
                        if !row.grid.isEmpty { Text(row.grid).font(.caption2) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text("\(row.total)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .sparkText()
            }
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let points = row.days.indices.contains(i) ? row.days[i] : -1
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(points > 0 ? Palette.amber.opacity(0.35 + 0.65 * min(Double(points) / 1500, 1)) : .white.opacity(0.08))
                            .frame(height: 6)
                        Text(dayLetters[i])
                            .font(.caption2.weight(i == todayIndex ? .heavy : .medium))
                            .foregroundStyle(i == todayIndex ? .white : Palette.muted)
                    }
                }
            }
        }
        .card(tint: row.isMe ? Palette.amber : nil, radius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(row.isMe ? "leagueRow-me" : "leagueRow-\(row.name)")
    }

    private var medal: Color {
        switch position {
        case 1: Color(hex: 0xFFD65A)
        case 2: Color(hex: 0xD8DEE9)
        case 3: Color(hex: 0xE3A36B)
        default: .white.opacity(0.15)
        }
    }
}

struct AddFriendSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onAdded: (String) -> Void

    @State private var text = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pega el mensaje que te ha enviado tu amigo (o solo el código que empieza por «CH1.»).")
                    .foregroundStyle(Palette.muted)
                PasteButton(payloadType: String.self) { strings in
                    guard let first = strings.first else { return }
                    Task { @MainActor in
                        text = first
                        add()
                    }
                }
                .buttonBorderShape(.capsule)
                .tint(Palette.ember)
                TextField("CH1.…", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("friendCodeField")
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.bad)
                        .accessibilityIdentifier("friendCodeError")
                }
                Button {
                    add()
                } label: {
                    Text("Añadir a mi liga").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.ember)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("confirmAddFriend")
                Spacer()
            }
            .padding(20)
            .background(NightBackground())
            .navigationTitle("Añadir amigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("closeAddFriend")
                }
            }
        }
    }

    private func add() {
        do {
            let friend = try store.importFriend(from: text)
            onAdded(friend.name)
            dismiss()
        } catch {
            withAnimation { self.error = (error as? LocalizedError)?.errorDescription ?? "Código no válido." }
        }
    }
}
