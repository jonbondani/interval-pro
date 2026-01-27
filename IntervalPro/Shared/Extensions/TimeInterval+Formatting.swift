import Foundation

extension TimeInterval {
    /// Format as MM:SS
    var formattedMinutesSeconds: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format as HH:MM:SS
    var formattedHoursMinutesSeconds: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format as "X min" or "X h Y min"
    var formattedDuration: String {
        let totalMinutes = Int(self) / 60

        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours) h"
            }
            return "\(hours) h \(minutes) min"
        }
    }

    /// Format pace as MM:SS /km
    var formattedPace: String {
        guard self > 0 && self < 3600 else { return "--:--" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
