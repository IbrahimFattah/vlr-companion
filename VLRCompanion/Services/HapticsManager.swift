import UIKit

enum Haptics {
    /// Fired when a followed team's match goes live.
    static func liveAlert() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
