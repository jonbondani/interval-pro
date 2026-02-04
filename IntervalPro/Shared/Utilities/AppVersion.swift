import Foundation

/// App version information helper
/// Provides version, build number, and build date for display in UI
enum AppVersion {
    /// App version from Info.plist (e.g., "1.0.0")
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Build number from Info.plist
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Build date formatted for display
    static var buildDate: String {
        // Use compile date as build date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "es_ES")

        // Get compile date from __DATE__ equivalent
        // In Swift, we use the file's last modification or a fixed date
        #if DEBUG
        return "Build: \(formatter.string(from: Date())) (Debug)"
        #else
        return "Build: \(formatter.string(from: Date()))"
        #endif
    }

    /// Full version string for logs
    static var fullVersionString: String {
        "IntervalPro v\(version) (\(build))"
    }

    /// Git commit hash (set via build script if available)
    static var commitHash: String {
        Bundle.main.infoDictionary?["GIT_COMMIT_HASH"] as? String ?? "dev"
    }
}
