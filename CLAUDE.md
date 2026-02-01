# CLAUDE.md - IntervalPro iOS

## Project Overview

**IntervalPro** is an iOS interval training app for runners focused on **cadence-based** HIIT workouts with Garmin Fenix integration and audio metronome overlay on streaming music.

**Target Release:** Q1 2026
**Min iOS:** 16.0
**Developer Account:** Free (no HealthKit)

---

## Key Concept: Cadence vs Heart Rate

**IMPORTANT:** The "BPM" values in this app (150, 160, 170, 180) are **RUNNING CADENCE** (steps per minute), NOT heart rate!

| Metric | Unit | Source | Purpose |
|--------|------|--------|---------|
| **Cadencia (SPM)** | Steps/min | Garmin RSC Service (0x1814) | Zone tracking, metronome sync |
| **FC (Heart Rate)** | Beats/min | Garmin HR Service (0x180D) | Display only (informational) |

```swift
// Zone tracking compares CADENCE vs target
// Example: Target 170 SPM ± 5
if currentCadence >= 165 && currentCadence <= 175 {
    // In zone - cadence is correct
}

// Heart rate is just displayed, NOT compared to zone
// FC: 145 lpm (informational)
```

---

## Tech Stack

### Core Frameworks (No External SDKs Required)

| Framework | Purpose | Notes |
|-----------|---------|-------|
| **SwiftUI** | UI layer | iOS 16+, no UIKit |
| **CoreBluetooth** | Garmin connection | Standard BLE, no Garmin SDK needed |
| **AVFoundation** | Metronome audio | AVAudioSession mixing |
| **CoreData** | Local persistence | Workout history storage |
| **Swift Charts** | Visualizations | Progress trends |

### What We DON'T Need

| SDK | Why Not Needed |
|-----|----------------|
| **HealthKit** | Requires paid dev account ($99/year). App stores workouts in CoreData locally. |
| **Garmin Connect IQ SDK** | Standard BLE HR (0x180D) and RSC (0x1814) services work without it |
| **Spotify SDK** | Uses MPNowPlayingInfoCenter for state + URL schemes. Spotify not accepting new devs anyway. |
| **Firebase** | Optional. Can add later for analytics if needed. |

### BLE Services Used (Standard Bluetooth, No SDK)

| Service | UUID | Characteristics | Data |
|---------|------|-----------------|------|
| Heart Rate | 0x180D | 0x2A37 | FC (beats/min) |
| Running Speed & Cadence | 0x1814 | 0x2A53 | Cadence (steps/min), Speed, Pace |

---

## Architecture

```
IntervalPro/
├── App/
│   └── IntervalProApp.swift
├── Features/
│   ├── Training/
│   │   ├── Views/          # TrainingView, CadenceZoneBar
│   │   ├── ViewModels/     # TrainingViewModel
│   │   └── Models/         # TrainingPlan, HeartRateZone (cadence zone)
│   ├── Plans/
│   ├── Progress/
│   └── Settings/
├── Core/
│   ├── Bluetooth/
│   │   └── GarminManager.swift     # Standard BLE, no SDK
│   ├── Health/
│   │   └── HRDataService.swift     # Unified cadence + HR stream
│   ├── Audio/
│   │   └── MetronomeEngine.swift
│   └── Persistence/
│       └── CoreDataStack.swift     # Local workout storage
├── Shared/
│   ├── Extensions/
│   ├── Components/
│   └── Utilities/
└── Tests/
```

---

## Immutable Rules

### 1. Cadence-Based Zone Tracking

```swift
// IMPORTANT: Zones are for CADENCE, not heart rate
struct HeartRateZone: Codable {  // Name kept for compatibility
    let targetBPM: Int      // Actually: target cadence in SPM
    let toleranceBPM: Int   // Tolerance in SPM

    var targetCadence: Int { targetBPM }  // Alias for clarity

    func status(for cadence: Int) -> ZoneStatus {
        if contains(cadence) { return .inZone }
        // ...
    }
}

// Zone feedback is about CADENCE:
// "Más rápido (+5 spm)" - increase step rate
// "Más lento (-3 spm)" - decrease step rate
// NOT about heart rate!
```

### 2. No External SDK Dependencies

```swift
// Garmin connection uses STANDARD CoreBluetooth
// No Garmin SDK download required

class GarminManager: NSObject, CBCentralManagerDelegate {
    // Scan for standard BLE services
    centralManager.scanForPeripherals(
        withServices: [
            CBUUID(string: "180D"),  // Heart Rate Service
            CBUUID(string: "1814")   // Running Speed & Cadence
        ],
        options: nil
    )
    // Works with ANY device that exposes these standard services
    // Including Garmin Fenix, Forerunner, HRM straps, etc.
}
```

### 3. Local-Only Storage (No HealthKit)

```swift
// Workouts stored in CoreData, NOT HealthKit
// This works with FREE developer account

class SessionRepository {
    func save(_ session: TrainingSession) async throws {
        // Save to CoreData
        let entity = TrainingSessionEntity(context: context)
        entity.id = session.id
        entity.date = session.date
        entity.duration = session.duration
        // ... all metrics stored locally
        try context.save()
    }
}

// HealthKit is NOT used because:
// 1. Requires paid developer account ($99/year)
// 2. App only needs to store workouts locally
// 3. User can manually log to Apple Health if desired
```

### 4. Graceful Degradation

```swift
// If Garmin not connected → use simulation mode
// If no music app → metronome still works
// If CoreData fails → show error, don't crash

func startWorkout() async throws {
    if garminManager.isConnected {
        // Real data from Garmin
        try await hrDataService.start()
    } else {
        // Simulated data for testing/demo
        hrDataService.enableSimulation(targetCadence: plan.workZone.targetCadence)
        Log.training.info("Using simulated data (no Garmin)")
    }
}
```

---

## Garmin Connection Guide

### For Users

1. **On Garmin watch**: Enable "Broadcast Heart Rate" (Transmitir FC)
   - Fenix: Hold UP → Settings → Sensors → Broadcast HR → ON
2. **On iPhone**: Open IntervalPro → Profile → Garmin → Search
3. Device should appear and auto-connect

### For Developers

The app uses standard BLE, not Garmin SDK:

```swift
// These standard services work without any SDK
let heartRateService = CBUUID(string: "180D")
let rscService = CBUUID(string: "1814")  // Running Speed & Cadence

// Device naming patterns to filter
let garminPatterns = ["garmin", "fenix", "forerunner", "hrm", "venu", "instinct"]
```

---

## Quick Reference

### Key Files

| File | Purpose |
|------|---------|
| `GarminManager.swift` | BLE connection (standard, no SDK) |
| `HRDataService.swift` | Unified cadence + HR stream, zone tracking |
| `MetronomeEngine.swift` | Audio playback, voice announcements |
| `IntervalTimer.swift` | Work/rest phase logic |
| `TrainingViewModel.swift` | Active session state |
| `TrainingPlan.swift` | Plan configuration |
| `HeartRateZone.swift` | Cadence zone model (name is legacy) |
| `CoreDataStack.swift` | Local persistence |
| `UnifiedMusicController.swift` | Music detection (no SDK) |

### Data Flow

```
Garmin Watch (BLE)
    ↓
GarminManager (CoreBluetooth)
    ↓
HRDataService (merges sources, zone tracking)
    ↓
TrainingViewModel (UI state)
    ↓
TrainingView (display)
    ↓
CoreData (save session locally)
```

---

## What Requires Paid Developer Account

| Feature | Free Account | Paid Account ($99/yr) |
|---------|--------------|----------------------|
| CoreBluetooth (Garmin) | ✅ Works | ✅ Works |
| CoreData (local storage) | ✅ Works | ✅ Works |
| AVFoundation (audio) | ✅ Works | ✅ Works |
| App Store distribution | ❌ No | ✅ Yes |
| HealthKit | ❌ No | ✅ Yes |
| TestFlight (beta) | ❌ No | ✅ Yes |

**Current status:** Free account. App works fully on device, just can't publish to App Store yet.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-27 | Initial CLAUDE.md |
| 1.1 | 2026-01-29 | Added WorkBlock for progressive workouts |
| 1.2 | 2026-01-30 | Music integration patterns |
| 1.3 | 2026-01-31 | **Major update**: Clarified cadence vs HR, removed HealthKit dependency, documented no SDK requirements |
