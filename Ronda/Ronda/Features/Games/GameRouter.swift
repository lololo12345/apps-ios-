import SwiftData
import SwiftUI

struct GameRouter: View {
    let game: ActiveGame

    var body: some View {
        switch game.kind {
        case .neverHave, .mostLikely, .truthOrDrink, .dares:
            PromptGameView(kind: game.kind, mode: game.mode)
        case .bomb:
            BombGameView(mode: game.mode)
        case .higherLower:
            HigherLowerGameView()
        case .circle:
            CircleGameView(mode: game.mode)
        case .duels:
            DuelsGameView()
        case .roulette:
            RouletteGameView(mode: game.mode)
        }
    }
}
