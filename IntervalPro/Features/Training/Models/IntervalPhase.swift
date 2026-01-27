import Foundation
import SwiftUI

/// Represents the current phase in an interval training session
enum IntervalPhase: String, Codable, Equatable, CaseIterable {
    case idle
    case warmup
    case work
    case rest
    case cooldown
    case complete

    // MARK: - Display Properties
    var displayName: String {
        switch self {
        case .idle: return "Preparado"
        case .warmup: return "Calentamiento"
        case .work: return "Trabajo"
        case .rest: return "Descanso"
        case .cooldown: return "Enfriamiento"
        case .complete: return "Completado"
        }
    }

    var shortName: String {
        switch self {
        case .idle: return "LISTO"
        case .warmup: return "WARM"
        case .work: return "WORK"
        case .rest: return "REST"
        case .cooldown: return "COOL"
        case .complete: return "FIN"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .warmup: return .orange
        case .work: return .red
        case .rest: return .green
        case .cooldown: return .blue
        case .complete: return .purple
        }
    }

    var icon: String {
        switch self {
        case .idle: return "play.circle"
        case .warmup: return "flame"
        case .work: return "bolt.heart.fill"
        case .rest: return "leaf.fill"
        case .cooldown: return "snowflake"
        case .complete: return "checkmark.seal.fill"
        }
    }

    // MARK: - Audio Announcements
    var startAnnouncement: String {
        switch self {
        case .idle: return ""
        case .warmup: return "Iniciando calentamiento"
        case .work: return "Iniciando trabajo"
        case .rest: return "Iniciando descanso"
        case .cooldown: return "Iniciando enfriamiento"
        case .complete: return "Entrenamiento completado"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .complete:
            return false
        case .warmup, .work, .rest, .cooldown:
            return true
        }
    }

    var isHighIntensity: Bool {
        self == .work
    }
}

// MARK: - Timer State
enum TimerState: Equatable {
    case stopped
    case running
    case paused

    var isRunning: Bool {
        self == .running
    }
}
