import Foundation
import Testing
@testable import Ronda

@MainActor
@Suite("PartySession")
struct SessionTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ronda.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func freshInstallAsksForAgeAndPlayers() {
        let session = PartySession(defaults: makeDefaults(), uiTesting: false)
        #expect(session.ageStatus == nil)
        #expect(session.players.isEmpty)
        #expect(!session.setupDone)
        #expect(session.waterEvery == 10)
    }

    @Test func minorsAreAlwaysSoberAndCannotUseHot() {
        let session = PartySession(defaults: makeDefaults(), uiTesting: false)
        session.ageStatus = .minor
        session.soberPreference = false
        #expect(session.soberMode)
        #expect(!session.canUseHot)
        session.ageStatus = .adult
        #expect(!session.soberMode)
        #expect(session.canUseHot)
    }

    @Test func playersAndTurnsAndNeighbours() {
        let session = PartySession(defaults: makeDefaults(), uiTesting: false)
        #expect(session.addPlayer(named: "Ana"))
        #expect(session.addPlayer(named: "Leo"))
        #expect(session.addPlayer(named: "Sara"))
        #expect(!session.addPlayer(named: "ana"))
        #expect(session.currentPlayer?.name == "Ana")
        session.nextTurn()
        #expect(session.currentPlayer?.name == "Leo")
        let leo = session.players[1]
        #expect(session.player(leftOf: leo)?.name == "Sara")
        #expect(session.player(rightOf: leo)?.name == "Ana")
    }

    @Test func persistsAcrossLaunches() {
        let defaults = makeDefaults()
        let first = PartySession(defaults: defaults, uiTesting: false)
        first.ageStatus = .adult
        first.addPlayer(named: "Ana")
        first.addPlayer(named: "Leo")
        first.setupDone = true
        first.give(3, to: first.players[0])
        first.waterEvery = 5

        let second = PartySession(defaults: defaults, uiTesting: false)
        #expect(second.ageStatus == .adult)
        #expect(second.players.map(\.name) == ["Ana", "Leo"])
        #expect(second.setupDone)
        #expect(second.ledger.count(for: second.players[0].id) == 3)
        #expect(second.waterEvery == 5)
    }

    @Test func waterBreaksOnlyWhenDrinking() {
        let session = PartySession(defaults: makeDefaults(), uiTesting: false)
        session.ageStatus = .adult
        session.waterEvery = 5
        for _ in 0..<5 { session.registerRound() }
        #expect(session.pendingWaterBreak != nil)

        let sober = PartySession(defaults: makeDefaults(), uiTesting: false)
        sober.ageStatus = .minor
        sober.waterEvery = 5
        for _ in 0..<10 { sober.registerRound() }
        #expect(sober.pendingWaterBreak == nil)
    }
}
