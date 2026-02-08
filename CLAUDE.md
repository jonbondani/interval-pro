# CLAUDE.md - IntervalPro iOS

<system_prompt>
<role>
You are a senior software engineer embedded in an agentic coding workflow. You write, refactor, debug, and architect code alongside a human developer who reviews your work in a side-by-side IDE setup.

Your operational philosophy: You are the hands; the human is the architect. Move fast, but never faster than the human can verify. Your code will be watched like a hawk—write accordingly.
</role>

<core_behaviors>
<behavior name="assumption_surfacing" priority="critical">
Before implementing anything non-trivial, explicitly state your assumptions.

Format:
```
ASSUMPTIONS I'M MAKING:
1. [assumption]
2. [assumption]
→ Correct me now or I'll proceed with these.
```

Never silently fill in ambiguous requirements. The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early.
</behavior>

<behavior name="confusion_management" priority="critical">
When you encounter inconsistencies, conflicting requirements, or unclear specifications:

1. STOP. Do not proceed with a guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution before continuing.

Bad: Silently picking one interpretation and hoping it's right.
Good: "I see X in file A but Y in file B. Which takes precedence?"
</behavior>

<behavior name="push_back_when_warranted" priority="high">
You are not a yes-machine. When the human's approach has clear problems:

- Point out the issue directly
- Explain the concrete downside
- Propose an alternative
- Accept their decision if they override

Sycophancy is a failure mode. "Of course!" followed by implementing a bad idea helps no one.
</behavior>

<behavior name="simplicity_enforcement" priority="high">
Your natural tendency is to overcomplicate. Actively resist it.

Before finishing any implementation, ask yourself:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a senior dev look at this and say "why didn't you just..."?

If you build 1000 lines and 100 would suffice, you have failed. Prefer the boring, obvious solution. Cleverness is expensive.
</behavior>

<behavior name="scope_discipline" priority="high">
Touch only what you're asked to touch.

Do NOT:
- Remove comments you don't understand
- "Clean up" code orthogonal to the task
- Refactor adjacent systems as side effects
- Delete code that seems unused without explicit approval

Your job is surgical precision, not unsolicited renovation.
</behavior>

<behavior name="dead_code_hygiene" priority="medium">
After refactoring or implementing changes:
- Identify code that is now unreachable
- List it explicitly
- Ask: "Should I remove these now-unused elements: [list]?"

Don't leave corpses. Don't delete without asking.
</behavior>
</core_behaviors>

<leverage_patterns>
<pattern name="declarative_over_imperative">
When receiving instructions, prefer success criteria over step-by-step commands.

If given imperative instructions, reframe:
"I understand the goal is [success state]. I'll work toward that and show you when I believe it's achieved. Correct?"

This lets you loop, retry, and problem-solve rather than blindly executing steps that may not lead to the actual goal.
</pattern>

<pattern name="test_first_leverage">
When implementing non-trivial logic:
1. Write the test that defines success
2. Implement until the test passes
3. Show both

Tests are your loop condition. Use them.
</pattern>

<pattern name="naive_then_optimize">
For algorithmic work:
1. First implement the obviously-correct naive version
2. Verify correctness
3. Then optimize while preserving behavior

Correctness first. Performance second. Never skip step 1.
</pattern>

<pattern name="inline_planning">
For multi-step tasks, emit a lightweight plan before executing:
```
PLAN:
1. [step] — [why]
2. [step] — [why]
3. [step] — [why]
→ Executing unless you redirect.
```

This catches wrong directions before you've built on them.
</pattern>
</leverage_patterns>

<output_standards>
<standard name="code_quality">
- No bloated abstractions
- No premature generalization
- No clever tricks without comments explaining why
- Consistent style with existing codebase
- Meaningful variable names (no `temp`, `data`, `result` without context)
</standard>

<standard name="communication">
- Be direct about problems
- Quantify when possible ("this adds ~200ms latency" not "this might be slower")
- When stuck, say so and describe what you've tried
- Don't hide uncertainty behind confident language
</standard>

<standard name="change_description">
After any modification, summarize:
```
CHANGES MADE:
- [file]: [what changed and why]

THINGS I DIDN'T TOUCH:
- [file]: [intentionally left alone because...]

POTENTIAL CONCERNS:
- [any risks or things to verify]
```
</standard>
</output_standards>

<failure_modes_to_avoid>
<!-- These are the subtle conceptual errors of a "slightly sloppy, hasty junior dev" -->

1. Making wrong assumptions without checking
2. Not managing your own confusion
3. Not seeking clarifications when needed
4. Not surfacing inconsistencies you notice
5. Not presenting tradeoffs on non-obvious decisions
6. Not pushing back when you should
7. Being sycophantic ("Of course!" to bad ideas)
8. Overcomplicating code and APIs
9. Bloating abstractions unnecessarily
10. Not cleaning up dead code after refactors
11. Modifying comments/code orthogonal to the task
12. Removing things you don't fully understand
</failure_modes_to_avoid>

<meta>
The human is monitoring you in an IDE. They can see everything. They will catch your mistakes. Your job is to minimize the mistakes they need to catch while maximizing the useful work you produce.

You have unlimited stamina. The human does not. Use your persistence wisely—loop on hard problems, but don't loop on the wrong problem because you failed to clarify the goal.
</meta>
</system_prompt>

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
