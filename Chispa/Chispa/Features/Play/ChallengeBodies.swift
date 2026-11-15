import SwiftUI

// MARK: - Multiple choice

struct ChoiceBody: View {
    let options: [String]
    let answer: Int
    let removed: Set<Int>
    let sound: Bool
    let onAnswer: (Bool) -> Void

    @State private var chosen: Int?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let hidden = removed.contains(index)
                Button {
                    choose(index)
                } label: {
                    HStack(spacing: 12) {
                        Text(["A", "B", "C", "D"][index % 4])
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.12), in: .circle)
                        Text(option)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let chosen, index == answer || index == chosen {
                            Image(systemName: index == answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(index == answer ? Palette.good : Palette.bad)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .card(tint: tint(for: index), radius: 20)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .disabled(chosen != nil || hidden)
                .opacity(hidden ? 0.25 : 1)
                .accessibilityIdentifier(LaunchOptions.revealAnswers && index == answer ? "answer-correct" : "answer-\(index)")
            }
        }
        .animation(.snappy(duration: 0.25), value: chosen)
        .animation(.smooth, value: removed)
    }

    private func tint(for index: Int) -> Color? {
        guard let chosen else { return nil }
        if index == answer { return Palette.good }
        if index == chosen { return Palette.bad }
        return nil
    }

    private func choose(_ index: Int) {
        guard chosen == nil else { return }
        Sounds.tap(enabled: sound)
        chosen = index
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            onAnswer(index == answer)
        }
    }
}

// MARK: - Number pad

struct NumberBody: View {
    let answer: Int
    let hint: String?
    let sound: Bool
    let onAnswer: (Int) -> Void

    @State private var text = ""
    @State private var sent = false

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]

    var body: some View {
        VStack(spacing: 14) {
            if let hint {
                Label(hint, systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .card(tint: Palette.amber, radius: 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("hintText")
            }
            Text(text.isEmpty ? "?" : text)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(text.isEmpty ? Palette.muted : .white)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .accessibilityIdentifier("numberDisplay")
                .accessibilityValue(LaunchOptions.revealAnswers ? "\(answer)" : text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        press(key)
                    } label: {
                        Group {
                            if key == "⌫" {
                                Image(systemName: "delete.left.fill")
                            } else {
                                Text(key)
                            }
                        }
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(key == "OK" ? Color(hex: 0x2A1300) : .white)
                        .background {
                            if key == "OK" {
                                RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: Palette.spark, startPoint: .leading, endPoint: .trailing))
                            }
                        }
                        .glassEffect(key == "OK" ? .identity : .regular.interactive(), in: .rect(cornerRadius: 18))
                        .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(sent || (key == "OK" && text.isEmpty))
                    .accessibilityLabel(key == "⌫" ? "Borrar" : key)
                    .accessibilityIdentifier("key-\(key == "⌫" ? "delete" : key)")
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: text)
    }

    private func press(_ key: String) {
        guard !sent else { return }
        Sounds.tap(enabled: sound)
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case "OK":
            guard let value = Int(text) else { return }
            sent = true
            onAnswer(value)
        default:
            if text.count < 6 { text = text == "0" ? key : text + key }
        }
    }
}

// MARK: - Memory grid

struct MemoryBody: View {
    let board: MemoryBoard
    /// When resuming an attempt the pattern is not shown again.
    let skipPreview: Bool
    /// Flips to true when the player asks to see the pattern again.
    let replayToken: Bool
    let sound: Bool
    let onFinish: (Double) -> Void

    @State private var lit: Set<Int> = []
    @State private var showing = false
    @State private var taps: [Int] = []
    @State private var wrongTap: Int?
    @State private var done = false
    @State private var countdown = 3

    var body: some View {
        VStack(spacing: 16) {
            Text(statusText)
                .font(.headline)
                .foregroundStyle(showing ? Palette.amber : .white)
                .contentTransition(.opacity)
                .accessibilityIdentifier("memoryStatus")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: board.columns), spacing: 10) {
                ForEach(0..<board.cellCount, id: \.self) { cell in
                    Button {
                        tap(cell)
                    } label: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(fill(for: cell))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if board.ordered, let order = taps.firstIndex(of: cell) {
                                    Text("\(order + 1)").font(.headline.weight(.heavy)).foregroundStyle(Color(hex: 0x10301F))
                                }
                            }
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                            .scaleEffect(lit.contains(cell) ? 1.06 : 1)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(showing || done)
                    .accessibilityIdentifier(identifier(for: cell))
                }
            }
            .animation(.snappy(duration: 0.18), value: lit)
            .animation(.snappy(duration: 0.18), value: taps)
            Text("\(taps.count) de \(board.targets.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
        }
        .task { if skipPreview { countdown = 0 } else { await preview() } }
        .onChange(of: replayToken) { _, replay in
            guard replay, !done else { return }
            taps = []
            Task { await preview(countdownFirst: false) }
        }
    }

    private var statusText: String {
        if done { return wrongTap == nil ? "¡Completo!" : "¡Fallo!" }
        if countdown > 0 { return "Atento… \(countdown)" }
        if showing { return board.ordered ? "Memoriza el orden" : "Memoriza las casillas" }
        return board.ordered ? "Tócalas en el mismo orden" : "Toca las casillas que se encendieron"
    }

    private func identifier(for cell: Int) -> String {
        guard LaunchOptions.revealAnswers, let order = board.targets.firstIndex(of: cell) else { return "cell-\(cell)" }
        return "target-\(order)"
    }

    private func fill(for cell: Int) -> Color {
        if cell == wrongTap { return Palette.bad }
        if taps.contains(cell) { return Palette.good }
        if lit.contains(cell) { return ChallengeKind.memory.tint }
        if done && board.targets.contains(cell) { return ChallengeKind.memory.tint.opacity(0.45) }
        return .white.opacity(0.06)
    }

    private func preview(countdownFirst: Bool = true) async {
        showing = true
        if countdownFirst {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(0.7))
                countdown -= 1
            }
        } else {
            countdown = 0
        }
        if board.ordered {
            for cell in board.targets {
                lit = [cell]
                try? await Task.sleep(for: .seconds(0.55))
                lit = []
                try? await Task.sleep(for: .seconds(0.15))
            }
        } else {
            lit = Set(board.targets)
            try? await Task.sleep(for: .seconds(board.showSeconds))
            lit = []
        }
        showing = false
    }

    private func tap(_ cell: Int) {
        guard !showing, !done else { return }
        if MemoryGenerator.isMistake(board: board, taps: taps, next: cell) {
            if taps.contains(cell) { return } // tapping an already found cell is ignored
            wrongTap = cell
            finish()
            return
        }
        Sounds.tap(enabled: sound)
        taps.append(cell)
        if taps.count == board.targets.count { finish() }
    }

    private func finish() {
        done = true
        let fraction = MemoryGenerator.fraction(board: board, taps: taps)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            onFinish(fraction)
        }
    }
}
