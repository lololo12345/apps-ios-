import UIKit

/// Thin wrapper over UIKit feedback generators that honors the in-app haptics setting.
@MainActor
enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PrefKey.haptics) as? Bool ?? true
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
