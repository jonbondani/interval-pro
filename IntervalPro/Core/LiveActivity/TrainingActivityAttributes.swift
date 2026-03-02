import ActivityKit
import Foundation

/// Live Activity attributes for an active training session.
/// This file must be added to BOTH the main app target AND the widget extension target.
struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseLabel: String        // "Trabajo", "Descanso", "Calentamiento", "Enfriamiento"
        var phaseEmoji: String        // "🏃", "🚶", "🔥", "❄️"
        var seriesNumber: Int
        var totalSeries: Int
        /// End date of the current phase — used for live countdown (no per-second updates needed)
        var phaseEndDate: Date
        var targetSPM: Int
        var currentPaceFormatted: String  // "5:30" or "--:--"
        var blockNumber: Int
        var totalBlocks: Int
    }

    var planName: String
}
