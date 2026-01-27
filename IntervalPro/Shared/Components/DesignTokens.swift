import SwiftUI

/// Design system tokens for consistent styling
/// Per CLAUDE.md: Use semantic fonts, never fixed sizes
enum DesignTokens {
    // MARK: - Typography
    enum Typography {
        /// Large heart rate display (72pt)
        static let hrDisplay: Font = .system(size: 72, weight: .bold, design: .rounded)

        /// Pace display (36pt)
        static let paceDisplay: Font = .system(size: 36, weight: .semibold, design: .monospaced)

        /// Timer display (48pt)
        static let timerDisplay: Font = .system(size: 48, weight: .bold, design: .monospaced)

        /// Phase indicator (24pt)
        static let phaseIndicator: Font = .system(size: 24, weight: .bold, design: .rounded)

        /// Section header
        static let sectionHeader: Font = .headline

        /// Body text
        static let body: Font = .body

        /// Caption
        static let caption: Font = .caption
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Minimum Tap Target
    /// Per CLAUDE.md: 44pt minimum tap target for accessibility
    static let minimumTapTarget: CGFloat = 44

    // MARK: - Animation
    enum Animation {
        static let quick: SwiftUI.Animation = .easeOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
        static let spring: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Colors (Semantic)
    enum Colors {
        // Zone colors
        static let zoneGreen = Color.green
        static let zoneYellow = Color.yellow
        static let zoneRed = Color.red
        static let zoneBlue = Color.blue

        // Phase colors
        static let workPhase = Color.red
        static let restPhase = Color.green
        static let warmupPhase = Color.orange
        static let cooldownPhase = Color.blue

        // UI colors
        static let cardBackground = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
    }
}

// MARK: - View Extensions
extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    /// Ensure minimum tap target size
    func accessibleTapTarget() -> some View {
        self.frame(
            minWidth: DesignTokens.minimumTapTarget,
            minHeight: DesignTokens.minimumTapTarget
        )
    }
}
