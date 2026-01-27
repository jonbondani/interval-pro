import os.log

/// Centralized logging infrastructure using os.Logger
/// Per CLAUDE.md: Never use print(), always use os.Logger
enum Log {
    // MARK: - Subsystem
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.intervalpro.app"

    // MARK: - Categories
    static let general = Logger(subsystem: subsystem, category: "general")
    static let bluetooth = Logger(subsystem: subsystem, category: "bluetooth")
    static let health = Logger(subsystem: subsystem, category: "health")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let training = Logger(subsystem: subsystem, category: "training")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let network = Logger(subsystem: subsystem, category: "network")

    // MARK: - Privacy-Safe HR Logging
    /// Log heart rate value with privacy protection
    /// In production, HR values are redacted
    static func logHeartRate(_ bpm: Int, context: String = "", logger: Logger = health) {
        #if DEBUG
        logger.debug("[\(context)] HR: \(bpm) bpm")
        #else
        logger.debug("[\(context)] HR: <redacted>")
        #endif
    }

    /// Log heart rate sample with full privacy protection
    static func logHRSample(_ sample: HRSample, logger: Logger = health) {
        #if DEBUG
        logger.debug("HR Sample - BPM: \(sample.bpm), Source: \(sample.source.rawValue), Time: \(sample.timestamp)")
        #else
        logger.debug("HR Sample received from \(sample.source.rawValue)")
        #endif
    }
}

// MARK: - HR Sample for Logging
struct HRSample: Codable, Equatable {
    let timestamp: Date
    let bpm: Int
    let source: DataSource

    init(timestamp: Date = Date(), bpm: Int, source: DataSource) {
        self.timestamp = timestamp
        self.bpm = bpm
        self.source = source
    }
}

enum DataSource: String, Codable {
    case garmin = "garmin"
    case healthKit = "healthkit"
    case watch = "watch"
    case simulated = "simulated"
}
