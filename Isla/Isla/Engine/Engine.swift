import Foundation

/// Turns a session into what the island shows, and applies the island's buttons.
extension ToolSession {
    // MARK: Display

    func display(now: Date = .now) -> IslaDisplay {
        switch state {
        case .countdown(let c): countdownDisplay(c, now: now)
        case .pomodoro(let p): pomodoroDisplay(p, now: now)
        case .stopwatch(let s): stopwatchDisplay(s, now: now)
        case .countUp(let c): countUpDisplay(c, now: now)
        case .counter(let c): counterDisplay(c)
        case .steps(let s): stepsDisplay(s, now: now)
        case .score(let s): scoreDisplay(s)
        case .turnClock(let t): turnDisplay(t, now: now)
        case .referee(let r):
            IslaDisplay(headline: title, value: r.result, buttons: [
                IslaButton("dice", "Dado", "die.face.5.fill"),
                IslaButton("coin", "Moneda", "circle.lefthalf.filled"),
            ] + (r.players.isEmpty ? [] : [IslaButton("who", "¿Quién?", "person.fill.questionmark", prominent: true)]))
        case .note(let text):
            IslaDisplay(headline: text, detail: title, buttons: [IslaButton("stop", "Quitar", "xmark")])
        case .worldClock(let w): worldDisplay(w, now: now)
        case .location(let l): locationDisplay(l, now: now)
        case .breathing(let b): breathingDisplay(b, now: now)
        case .event(let e):
            IslaDisplay(
                headline: e.title,
                detail: e.location.isEmpty ? "Empieza a las \(Fmt.time(e.start))" : "\(Fmt.time(e.start)) · \(e.location)",
                timer: e.start > now ? IslaTimer(start: now, end: e.start, countsDown: true) : nil,
                buttons: [IslaButton("nextEvent", "Siguiente", "forward.fill")],
                finished: e.start <= now
            )
        }
    }

    private func countdownDisplay(_ c: CountdownState, now: Date) -> IslaDisplay {
        let remaining = c.remaining(now)
        let done = remaining <= 0
        let timer = IslaTimer(start: c.start, end: c.end, countsDown: true, frozen: c.paused)
        let progress: IslaProgress = c.paused != nil ? .value(1 - remaining / max(c.total, 1)) : .timer(c.start, c.end)
        let pause = c.paused == nil ? IslaButton("pause", "Pausa", "pause.fill") : IslaButton("resume", "Seguir", "play.fill", prominent: true)
        var display = IslaDisplay(headline: title, detail: c.note.isEmpty ? nil : c.note, timer: done ? nil : timer, progress: progress,
                                  buttons: [pause, IslaButton("plus1", "+1 min", "plus")], finished: done)
        switch kind {
        case .pill:
            display.detail = "Próxima toma · \(Fmt.time(c.end))"
            display.buttons = [IslaButton("taken", "Tomada", "checkmark", prominent: true)]
        case .parking:
            display.detail = c.note.isEmpty ? "Caduca a las \(Fmt.time(c.end))" : "\(c.note) · hasta las \(Fmt.time(c.end))"
            display.buttons = [IslaButton("plus30", "+30 min", "plus"), IslaButton("stop", "Me voy", "car.fill")]
        case .movie:
            display.detail = "Termina a las \(Fmt.time(c.end))"
            display.buttons = [pause]
        case .charging:
            display.detail = "\(c.batteryFrom) % → \(c.batteryTo) % a las \(Fmt.time(c.end))"
            display.buttons = [IslaButton("stop", "Desenchufado", "powerplug.fill")]
        case .presentation:
            let elapsed = c.total - remaining
            let expected = min(c.parts, Int(elapsed / max(c.total, 1) * Double(c.parts)) + 1)
            let pace = c.part > expected ? "vas adelantado" : (c.part < expected ? "deberías ir por la \(expected)" : "vas bien")
            display.detail = "Parte \(c.part) de \(c.parts) · \(pace)"
            display.buttons = [IslaButton("nextPart", "Siguiente parte", "forward.fill", prominent: true), pause]
        case .flight:
            display.headline = "Embarque · \(title)"
            display.detail = c.note.isEmpty ? "A las \(Fmt.time(c.end))" : c.note
            display.buttons = []
        case .nap:
            display.detail = "Te despierto a las \(Fmt.time(c.end))"
            display.buttons = [IslaButton("plus5", "+5 min", "zzz"), IslaButton("stop", "Ya estoy", "sun.max.fill")]
        default: break
        }
        if done {
            display.headline = kind == .pill ? "Hora de la toma" : (kind == .nap ? "¡Arriba!" : "Se acabó el tiempo")
            if kind != .pill && kind != .nap { display.detail = title }
            display.value = "0:00"
            if kind == .timer || kind == .appliance { display.buttons = [IslaButton("restart", "Otra vez", "arrow.clockwise"), IslaButton("stop", "Quitar", "xmark")] }
        }
        return display
    }

    private func pomodoroDisplay(_ p: PomodoroState, now: Date) -> IslaDisplay {
        let length = p.length(p.phase)
        let remaining = p.paused ?? max(0, p.phaseEnd.timeIntervalSince(now))
        let start = p.phaseEnd.addingTimeInterval(-length)
        if remaining <= 0 {
            // The phase ended while the app was closed: offer the next one instead of a frozen 0:00.
            let next = p.phase == .work ? "¡Descanso!" : "Vuelta al foco"
            return IslaDisplay(headline: next, detail: "\(p.completed + (p.phase == .work ? 1 : 0)) pomodoros hoy", value: "0:00",
                               progress: .value(1),
                               buttons: [IslaButton("skip", p.phase == .work ? "Descansar" : "Empezar", "play.fill", prominent: true)],
                               finished: true, symbol: p.phase == .work ? "cup.and.saucer.fill" : "brain.head.profile")
        }
        let headline = p.phase == .work ? "Foco · ronda \(p.round)" : (p.phase == .longBreak ? "Descanso largo" : "Descanso")
        return IslaDisplay(
            headline: headline,
            detail: "\(p.completed) pomodoros hoy",
            timer: IslaTimer(start: start, end: p.phaseEnd, countsDown: true, frozen: p.paused),
            progress: p.paused != nil ? .value(1 - remaining / length) : .timer(start, p.phaseEnd),
            buttons: [p.paused == nil ? IslaButton("pause", "Pausa", "pause.fill") : IslaButton("resume", "Seguir", "play.fill", prominent: true),
                      IslaButton("skip", "Saltar", "forward.end.fill")],
            symbol: p.phase == .work ? "brain.head.profile" : "cup.and.saucer.fill"
        )
    }

    private func stopwatchDisplay(_ s: StopwatchState, now: Date) -> IslaDisplay {
        let last = s.laps.last.map { "Última vuelta \(Fmt.clock($0))" }
        return IslaDisplay(
            headline: title,
            detail: s.laps.isEmpty ? nil : "Vuelta \(s.laps.count + 1) · \(last ?? "")",
            timer: IslaTimer(start: s.start, end: s.start.addingTimeInterval(24 * 3600), countsDown: false, frozen: s.paused),
            buttons: [IslaButton("lap", "Vuelta", "flag.fill", prominent: true),
                      s.paused == nil ? IslaButton("pause", "Pausa", "pause.fill") : IslaButton("resume", "Seguir", "play.fill")]
        )
    }

    private func countUpDisplay(_ c: CountUpState, now: Date) -> IslaDisplay {
        if kind == .fasting {
            let hours = now.timeIntervalSince(c.start) / 3600
            let goalEnd = c.start.addingTimeInterval(c.goalHours * 3600)
            return IslaDisplay(
                headline: FastingPhase.label(hours: hours),
                detail: "Objetivo \(Int(c.goalHours)) h · \(Fmt.time(goalEnd))",
                timer: .countUp(from: c.start),
                progress: .timer(c.start, goalEnd),
                buttons: [IslaButton("stop", "Romper el ayuno", "fork.knife", prominent: true)],
                finished: now >= goalEnd
            )
        }
        let today = c.history.filter { Calendar.current.isDate($0, inSameDayAs: now) }.count
        return IslaDisplay(
            headline: title,
            detail: "Desde las \(Fmt.time(c.start))" + (today > 0 ? " · \(today) hoy" : ""),
            timer: .countUp(from: c.start),
            buttons: [IslaButton("reset", "Otra vez", "arrow.counterclockwise", prominent: true)]
        )
    }

    private func counterDisplay(_ c: CounterState) -> IslaDisplay {
        let value = Fmt.number(c.value, money: c.money)
        var display = IslaDisplay(headline: title, value: value,
                                  progress: c.goal > 0 ? .value(min(1, c.value / c.goal)) : nil,
                                  buttons: [IslaButton("minus", "−\(Fmt.number(c.step, money: false))", "minus"),
                                            IslaButton("plus", "+\(Fmt.number(c.step, money: false))", "plus", prominent: true)])
        if c.goal > 0 { display.detail = "Objetivo \(Fmt.number(c.goal, money: c.money))" }
        if kind == .expense {
            let left = c.goal - c.value
            display.detail = c.goal > 0 ? (left >= 0 ? "Quedan \(Fmt.number(left, money: true)) de \(Fmt.number(c.goal, money: true))" : "Te has pasado \(Fmt.number(-left, money: true))") : nil
            display.buttons = c.amounts.prefix(2).map { IslaButton("add:\($0)", "+\(Fmt.number($0, money: true))", "plus") }
                + [IslaButton("undo", "Deshacer", "arrow.uturn.backward")]
            display.finished = c.goal > 0 && c.value > c.goal
        }
        return display
    }

    private func stepsDisplay(_ s: StepsState, now: Date) -> IslaDisplay {
        guard let item = s.current else {
            let summary = kind == .flashcards ? "\(s.right) bien · \(s.wrong) mal" : "\(s.items.count) de \(s.items.count)"
            return IslaDisplay(headline: "¡Completado!", detail: summary, value: "✓",
                               buttons: [IslaButton("restart", "Empezar de nuevo", "arrow.clockwise"), IslaButton("stop", "Quitar", "xmark")], finished: true)
        }
        let position = "\(s.index + 1) de \(s.items.count)"
        // Short progress for the compact island ("2/5"), where long text would be cut.
        let short = "\(s.index + 1)/\(s.items.count)"
        switch kind {
        case .flashcards:
            return IslaDisplay(headline: item.text, detail: s.revealed ? item.detail : "Tarjeta \(position) · toca para ver la respuesta", value: short,
                               progress: .value(Double(s.index) / Double(s.items.count)),
                               buttons: s.revealed ? [IslaButton("wrong", "No", "xmark"), IslaButton("right", "La sabía", "checkmark", prominent: true)]
                                   : [IslaButton("reveal", "Ver respuesta", "eye.fill", prominent: true)])
        case .workout:
            if let restEnd = s.restEnd, restEnd > now {
                return IslaDisplay(headline: "Descanso · \(item.text)", detail: "Siguiente: serie \(s.set) de \(s.sets)",
                                   timer: IslaTimer(start: restEnd.addingTimeInterval(-s.rest), end: restEnd, countsDown: true),
                                   progress: .timer(restEnd.addingTimeInterval(-s.rest), restEnd),
                                   buttons: [IslaButton("skipRest", "Ya", "forward.fill", prominent: true)])
            }
            return IslaDisplay(headline: item.text, detail: "Serie \(s.set) de \(s.sets) · ejercicio \(position)",
                               progress: .value(Double(s.index * s.sets + s.set - 1) / Double(max(1, s.items.count * s.sets))),
                               buttons: [IslaButton("setDone", "Serie hecha", "checkmark", prominent: true)])
        case .recipe:
            var display = IslaDisplay(headline: "Paso \(position)", detail: item.text, value: short,
                                      progress: .value(Double(s.index) / Double(s.items.count)),
                                      buttons: [IslaButton("back", "Atrás", "backward.fill"), IslaButton("next", "Siguiente", "forward.fill", prominent: true)])
            if let end = s.stepTimerEnd, end > now {
                display.timer = IslaTimer(start: end.addingTimeInterval(-item.minutes * 60), end: end, countsDown: true)
            } else if item.minutes > 0 {
                display.buttons.insert(IslaButton("stepTimer", "\(Fmt.number(item.minutes, money: false)) min", "timer"), at: 1)
            }
            return display
        case .shopping:
            return IslaDisplay(headline: item.text, detail: "\(position)" + (item.detail.isEmpty ? "" : " · \(item.detail)"), value: short,
                               progress: .value(Double(s.index) / Double(s.items.count)),
                               buttons: [IslaButton("skip", "Luego", "arrow.uturn.down"), IslaButton("next", "Cogido", "checkmark", prominent: true)])
        default:
            return IslaDisplay(headline: item.text, detail: "Tarea \(position)", value: short,
                               progress: .value(Double(s.index) / Double(s.items.count)),
                               buttons: [IslaButton("next", "Hecho", "checkmark", prominent: true)])
        }
    }

    private func scoreDisplay(_ s: ScoreState) -> IslaDisplay {
        let buttons = [IslaButton("a", Self.short(s.names[0]), "plus.circle.fill", prominent: true),
                       IslaButton("b", Self.short(s.names[1]), "plus.circle.fill", prominent: true),
                       IslaButton("undo", "", "arrow.uturn.backward")]
        if s.racket {
            if let winner = s.match.winner {
                return IslaDisplay(headline: "¡Gana \(s.names[winner])!", detail: s.match.setsText, value: s.match.setsText, buttons: [buttons[2]], finished: true)
            }
            return IslaDisplay(headline: "\(s.names[0]) vs \(s.names[1])",
                               detail: (s.match.tieBreak ? "Tie-break · " : "") + "Sets y juegos \(s.match.setsText)",
                               value: "\(s.match.pointLabel(0)) – \(s.match.pointLabel(1))", buttons: buttons)
        }
        return IslaDisplay(headline: "\(s.names[0]) vs \(s.names[1])", value: "\(s.points[0]) – \(s.points[1])", buttons: buttons)
    }

    private func turnDisplay(_ t: TurnClockState, now: Date) -> IslaDisplay {
        let left = t.left(t.current, now: now)
        let others = t.players.indices.filter { $0 != t.current }.map { "\(t.players[$0]) \(Fmt.clock(t.left($0, now: now)))" }
        return IslaDisplay(
            headline: "Turno de \(t.players[t.current])",
            detail: others.joined(separator: " · "),
            timer: IslaTimer(start: now, end: now.addingTimeInterval(left), countsDown: true, frozen: t.paused ? left : nil),
            buttons: [IslaButton("next", "Pasar turno", "arrow.right.circle.fill", prominent: true),
                      t.paused ? IslaButton("resume", "Seguir", "play.fill") : IslaButton("pause", "Pausa", "pause.fill")],
            finished: left <= 0
        )
    }

    private func worldDisplay(_ w: WorldClockState, now: Date) -> IslaDisplay {
        let zone = TimeZone(identifier: w.timeZone) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let midnight = calendar.startOfDay(for: now)
        let diff = (zone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)) / 3600
        let offset = diff == 0 ? "misma hora que tú" : (diff > 0 ? "+\(diff) h respecto a ti" : "\(diff) h respecto a ti")
        // A count-up from that city's midnight *is* its local time, and the system animates it with no updates.
        return IslaDisplay(headline: w.city, detail: offset, timer: IslaTimer(start: midnight, end: midnight.addingTimeInterval(24 * 3600), countsDown: false),
                           buttons: [IslaButton("stop", "Quitar", "xmark")])
    }

    private func locationDisplay(_ l: LocationState, now: Date) -> IslaDisplay {
        switch kind {
        case .speed:
            let kmh = max(0, l.speed * 3.6)
            return IslaDisplay(headline: title, detail: Geo.format(l.travelled), value: String(format: "%.1f km/h", kmh).replacingOccurrences(of: ".", with: ","),
                               timer: .countUp(from: l.started), buttons: [IslaButton("stop", "Terminar", "stop.fill", prominent: true)])
        case .backToCar:
            let rotation = l.bearing.map { $0 - (l.heading ?? 0) }
            return IslaDisplay(headline: "Tu coche", detail: l.targetName.isEmpty ? "Aparcado a las \(Fmt.time(l.started))" : l.targetName,
                               value: l.distance.map(Geo.format) ?? "…", buttons: [IslaButton("stop", "Ya estoy", "checkmark", prominent: true)],
                               finished: (l.distance ?? .infinity) < 25, symbol: "location.north.fill", rotation: rotation)
        default:
            let arriving = (l.distance ?? .infinity) <= l.radius
            return IslaDisplay(headline: arriving ? "¡Tu parada!" : "Hacia \(l.targetName)",
                               detail: arriving ? "Prepárate para bajar" : "Te aviso a \(Geo.format(l.radius))",
                               value: l.distance.map(Geo.format) ?? "…", buttons: [IslaButton("stop", "Cancelar", "xmark")], finished: arriving)
        }
    }

    private func breathingDisplay(_ b: BreathingState, now: Date) -> IslaDisplay {
        let elapsed = now.timeIntervalSince(b.start)
        let phase = b.pattern.phase(at: max(0, elapsed))
        let done = now >= b.end
        return IslaDisplay(
            headline: done ? "Bien hecho" : phase.label,
            detail: b.pattern.title,
            timer: done ? nil : IslaTimer(start: b.start, end: b.end, countsDown: true),
            progress: done ? .value(1) : .timer(b.start.addingTimeInterval(phase.start), b.start.addingTimeInterval(phase.end)),
            buttons: [IslaButton("stop", done ? "Cerrar" : "Parar", "xmark")],
            finished: done,
            symbol: "wind"
        )
    }

    /// Team names on buttons: first word, at most 9 letters, so two buttons and «deshacer» fit.
    static func short(_ name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return first.count > 9 ? String(first.prefix(8)) + "." : first
    }

    /// Which activity the island should prefer when several are running (higher = more urgent).
    func relevance(now: Date = .now) -> Double {
        guard let alert = alertDate(now: now) else { return 10 }
        let minutes = max(0, alert.date.timeIntervalSince(now) / 60)
        return 100 + max(0, 1000 - minutes)
    }

    // MARK: Actions

    /// Applies a button from the island (or the app). Returns false when the session should end.
    mutating func handle(_ action: String, now: Date = .now) -> Bool {
        if action == "stop" { return false }
        switch state {
        case .countdown(var c):
            switch action {
            case "pause": c.paused = c.remaining(now)
            case "resume":
                if let paused = c.paused { c.end = now.addingTimeInterval(paused); c.paused = nil }
            case "plus1", "plus5", "plus30":
                let extra: TimeInterval = action == "plus1" ? 60 : (action == "plus5" ? 300 : 1800)
                if c.remaining(now) <= 0 { c.end = now }
                c.total += extra
                if let paused = c.paused { c.paused = paused + extra } else { c.end += extra }
            case "restart", "taken":
                c.end = now.addingTimeInterval(c.total)
                c.paused = nil
            case "nextPart": c.part = min(c.parts, c.part + 1)
            default: break
            }
            state = .countdown(c)
        case .pomodoro(var p):
            switch action {
            case "pause": p.paused = max(0, p.phaseEnd.timeIntervalSince(now))
            case "resume":
                if let paused = p.paused { p.phaseEnd = now.addingTimeInterval(paused); p.paused = nil }
            case "skip", "tick": p.advance(now: now)
            default: break
            }
            state = .pomodoro(p)
        case .stopwatch(var s):
            switch action {
            case "lap":
                let total = s.elapsed(now)
                s.laps.append(total - s.laps.reduce(0, +))
            case "pause": s.paused = s.elapsed(now)
            case "resume":
                if let paused = s.paused { s.start = now.addingTimeInterval(-paused); s.paused = nil }
            default: break
            }
            state = .stopwatch(s)
        case .countUp(var c):
            if action == "reset" {
                c.history.append(c.start)
                c.start = now
            }
            state = .countUp(c)
        case .counter(var c):
            switch action {
            case "plus": c.value += c.step; c.log.append(c.step)
            case "minus": c.value = max(c.money ? 0 : -1_000_000, c.value - c.step); c.log.append(-c.step)
            case "undo":
                if let last = c.log.popLast() { c.value -= last }
            default:
                if action.hasPrefix("add:"), let amount = Double(action.dropFirst(4)) { c.value += amount; c.log.append(amount) }
            }
            state = .counter(c)
        case .steps(var s):
            switch action {
            case "next", "right", "wrong":
                if action == "right" { s.right += 1 }
                if action == "wrong" { s.wrong += 1 }
                s.index += 1
                s.revealed = false
                s.stepTimerEnd = nil
            case "skip":
                // Shopping: move the item to the end of the list.
                if let item = s.current, s.index < s.items.count - 1 { s.items.remove(at: s.index); s.items.append(item) }
            case "back": s.index = max(0, s.index - 1); s.stepTimerEnd = nil
            case "reveal": s.revealed = true
            case "stepTimer":
                if let item = s.current, item.minutes > 0 { s.stepTimerEnd = now.addingTimeInterval(item.minutes * 60) }
            case "setDone":
                if s.set >= s.sets {
                    s.set = 1
                    s.index += 1
                } else {
                    s.set += 1
                }
                s.restEnd = s.isFinished || s.rest <= 0 ? nil : now.addingTimeInterval(s.rest)
            case "skipRest": s.restEnd = nil
            case "restart": s.index = 0; s.right = 0; s.wrong = 0; s.set = 1; s.revealed = false
            default: break
            }
            state = .steps(s)
        case .score(var s):
            switch action {
            case "a", "b":
                let side = action == "a" ? 0 : 1
                if s.racket {
                    s.matchHistory.append(s.match)
                    s.match.point(side)
                } else {
                    s.pointsHistory.append(s.points)
                    s.points[side] += 1
                }
            case "undo":
                if s.racket, let last = s.matchHistory.popLast() { s.match = last }
                if !s.racket, let last = s.pointsHistory.popLast() { s.points = last }
            default: break
            }
            state = .score(s)
        case .turnClock(var t):
            switch action {
            case "next":
                t.remaining[t.current] = t.left(t.current, now: now)
                t.current = (t.current + 1) % t.players.count
                t.turnStart = now
                t.paused = false
            case "pause":
                t.remaining[t.current] = t.left(t.current, now: now)
                t.paused = true
            case "resume":
                t.turnStart = now
                t.paused = false
            default: break
            }
            state = .turnClock(t)
        case .referee(var r):
            var generator = SplitMix(seed: r.seed &+ UInt64(now.timeIntervalSince1970 * 1000))
            r.seed = generator.next()
            switch action {
            case "dice": r.result = "🎲 \(Int(generator.next() % 6) + 1)"
            case "coin": r.result = generator.next() % 2 == 0 ? "Cara" : "Cruz"
            case "who":
                if !r.players.isEmpty { r.result = "Le toca a \(r.players[Int(generator.next() % UInt64(r.players.count))])" }
            default: break
            }
            state = .referee(r)
        case .location, .breathing, .note, .worldClock, .event:
            break
        }
        return true
    }

    /// When a notification should fire for this session (nil = none).
    func alertDate(now: Date = .now) -> (date: Date, title: String, body: String)? {
        switch state {
        case .countdown(let c) where c.paused == nil:
            switch kind {
            case .parking: return (c.end.addingTimeInterval(-600), "El ticket caduca en 10 min", title)
            case .flight: return (c.end.addingTimeInterval(-900), "Embarque en 15 min", c.note.isEmpty ? title : c.note)
            case .pill: return (c.end, "Hora de tu toma", title)
            case .nap: return (c.end, "¡Arriba!", "Fin de la siesta")
            case .presentation: return (c.end, "Se acabó el tiempo", title)
            default: return (c.end, "Se acabó el tiempo", title)
            }
        case .pomodoro(let p) where p.paused == nil:
            return (p.phaseEnd, p.phase == .work ? "¡Descanso!" : "Vuelta al foco", p.phase == .work ? "Has terminado un pomodoro." : "Empieza la ronda \(p.round + 1).")
        case .countUp(let c) where kind == .fasting:
            return (c.start.addingTimeInterval(c.goalHours * 3600), "¡Objetivo de ayuno cumplido!", "\(Int(c.goalHours)) horas")
        case .steps(let s):
            if let rest = s.restEnd { return (rest, "Siguiente serie", s.current?.text ?? title) }
            if let step = s.stepTimerEnd { return (step, "Paso listo", s.current?.text ?? title) }
            return nil
        case .turnClock(let t) where !t.paused:
            return (now.addingTimeInterval(t.left(t.current, now: now)), "Se acabó el tiempo", "Turno de \(t.players[t.current])")
        case .breathing(let b):
            return (b.end, "Respiración terminada", "Bien hecho 🌬️")
        case .event(let e):
            return (e.start.addingTimeInterval(-600), "En 10 minutos", e.title)
        default:
            return nil
        }
    }

    /// The moment the island content stops being accurate without an app update (Live Activity stale date).
    func staleDate(now: Date = .now) -> Date? {
        alertDate(now: now).map { max($0.date, now) }
    }
}

/// Small deterministic generator (SplitMix64).
struct SplitMix: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
