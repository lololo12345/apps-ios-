import Foundation

/// Plain-Swift logic (no SwiftUI/UIKit) shared by the app and the widget.
/// Keep it Foundation-only so `tools/check_swift.sh __name__` can type-check it on Linux in seconds.
enum __name__Info {
    static let name = "__display__"
    static let urlScheme = "__scheme__"
}
