# PLAN.md - IntervalPro Development Plan

## Overview

**Project:** IntervalPro iOS
**Developer Account:** Free (no HealthKit, no App Store until upgrade)
**iOS Target:** 16.0+
**Bundle ID:** com.jbd.intervalpro.app

---

## Key Clarifications

### Cadence vs Heart Rate

**IMPORTANTE:** Los valores BPM (150, 160, 170, 180) son **CADENCIA** (pasos por minuto), NO frecuencia cardíaca.

| Métrica | Unidad | Fuente | Uso |
|---------|--------|--------|-----|
| **Cadencia** | SPM (pasos/min) | Garmin RSC (0x1814) | Tracking de zonas, metrónomo |
| **FC** | lpm (latidos/min) | Garmin HR (0x180D) | Solo mostrar (informativo) |

### SDKs Externos

**NO se requiere ningún SDK externo:**

| SDK | Estado | Motivo |
|-----|--------|--------|
| Garmin Connect IQ | ❌ No necesario | CoreBluetooth estándar funciona |
| Spotify SDK | ❌ No necesario | MPNowPlayingInfoCenter + URL schemes |
| HealthKit | ❌ No disponible | Requiere cuenta de pago ($99/año) |
| Firebase | ⏳ Opcional | Para analytics, se puede añadir después |

---

## Milestones Actualizados

| Milestone | Estado | Descripción |
|-----------|--------|-------------|
| **M1: MVP Timer** | ✅ COMPLETO | Timer, simulación, metrónomo, UI básica |
| **M2: Garmin Real** | 🔄 EN PROGRESO | Conexión BLE real con Fenix 3HR |
| **M3: Histórico** | ⏳ Pendiente | CoreData sessions, progress charts |
| **M4: App Store** | ⏳ Requiere cuenta de pago | Publicación |

---

## Estado Actual del Proyecto

### ✅ Completado

- [x] Estructura de proyecto Xcode
- [x] SwiftLint configurado
- [x] Modelo CoreData (TrainingPlan, TrainingSession)
- [x] IntervalTimer con fases (warmup, work, rest, cooldown)
- [x] MetronomeEngine con audio mixing
- [x] Voice announcements (AVSpeechSynthesizer)
- [x] HRDataService con modo simulación
- [x] TrainingView con cadencia + FC separados
- [x] HomeView con planes de entrenamiento
- [x] GarminManager con CoreBluetooth estándar
- [x] Detección de música (Spotify/Apple Music)
- [x] Onboarding flow con permisos
- [x] ProfileView con ajustes de conexión

### 🔄 En Progreso

- [ ] **Conexión real Garmin Fenix 3HR**
  - GarminManager implementado
  - Necesita testing con dispositivo real
  - Usuario debe activar "Transmitir FC" en el reloj

### ⏳ Pendiente

- [ ] SessionRepository para guardar entrenamientos
- [ ] Progress charts con Swift Charts
- [ ] Exportar a Strava (opcional)

### ❌ Eliminado/Pospuesto

- [-] HealthKit (requiere cuenta de pago)
- [-] Spotify SDK OAuth (Spotify no acepta nuevos devs)
- [-] Garmin Connect IQ SDK (no necesario)

---

## Arquitectura Simplificada

```
┌─────────────────────────────────────────────────────────┐
│                    IntervalPro App                       │
├─────────────────────────────────────────────────────────┤
│  TrainingView                                            │
│  ├── Cadencia Display (SPM) + Zone Bar                  │
│  ├── FC Display (lpm) - solo informativo                │
│  ├── Timer + Phase Indicator                            │
│  └── Music Widget (read-only for Spotify)               │
├─────────────────────────────────────────────────────────┤
│  TrainingViewModel                                       │
│  ├── Bindings from HRDataService                        │
│  ├── IntervalTimer control                              │
│  └── Audio coordination                                 │
├─────────────────────────────────────────────────────────┤
│  HRDataService (Unified Data)                           │
│  ├── Cadence → Zone Status (tracking)                   │
│  ├── Heart Rate → Display only                          │
│  └── Source: Garmin OR Simulation                       │
├─────────────────────────────────────────────────────────┤
│  GarminManager (CoreBluetooth)                          │
│  ├── HR Service (0x180D) → FC                           │
│  ├── RSC Service (0x1814) → Cadencia, Velocidad         │
│  └── Auto-reconnect con backoff                         │
├─────────────────────────────────────────────────────────┤
│  CoreData (Local Storage)                               │
│  └── TrainingSession, IntervalRecord                    │
└─────────────────────────────────────────────────────────┘
```

---

## Conexión Garmin - Checklist

### Para que funcione:

1. **En el reloj Garmin:**
   - Mantener pulsado UP → Configuración
   - Sensores y Accesorios → Transmitir FC → Activar
   - Debe aparecer icono de corazón con ondas

2. **En la app:**
   - Perfil → Garmin → Buscar dispositivos
   - El dispositivo debería aparecer como "Fenix" o similar
   - Pulsar para conectar

3. **Verificación:**
   - Indicador verde "Garmin" en TrainingView
   - Cadencia y FC mostrando valores reales

### Troubleshooting:

| Problema | Solución |
|----------|----------|
| No encuentra dispositivo | Activar "Transmitir FC" en el reloj |
| Conecta pero no hay datos | Verificar que el servicio RSC esté activo |
| Se desconecta | El reloj tiene timeout, mantener activo |

---

## Dependencias del Proyecto

### Swift Packages (Actuales)

```swift
// Package.swift o SPM en Xcode
// Actualmente NO hay dependencias externas
// Todo usa frameworks nativos de Apple
```

### Frameworks Nativos Usados

| Framework | Propósito |
|-----------|-----------|
| SwiftUI | UI |
| CoreBluetooth | Garmin BLE |
| AVFoundation | Audio |
| CoreData | Persistencia |
| Speech | Voice announcements |
| MediaPlayer | Music detection |

---

## Próximos Pasos Inmediatos

### Prioridad 1: Verificar Garmin
1. Probar conexión con Fenix 3HR real
2. Verificar que llegan datos de cadencia (RSC service)
3. Verificar que llegan datos de FC (HR service)

### Prioridad 2: Guardar Entrenamientos
1. Implementar SessionRepository.save()
2. Guardar session al completar/parar entrenamiento
3. Mostrar historial en ProgressView

### Prioridad 3: Mejoras UI
1. Ajustar tamaños para visibilidad exterior
2. Mejorar feedback de zona (haptics)
3. Landscape mode para training

---

## Costes y Requisitos

| Requisito | Coste | Estado |
|-----------|-------|--------|
| Mac con Xcode | $0 | ✅ Disponible |
| iPhone para testing | $0 | ✅ Disponible |
| Garmin Fenix 3HR | $0 | ✅ Disponible |
| Apple Developer (free) | $0 | ✅ Activo |
| Apple Developer (paid) | $99/año | ⏳ Para App Store |

---

---

## Funcionalidades Futuras

### F1: Playlist Inteligente por Cadencia (Prioridad Alta)

**Descripción:** Analizar una playlist de Spotify/Apple Music y crear automáticamente una lista optimizada para el entrenamiento según los BPM de cada canción y las fases del workout.

**Ejemplo de uso:**
```
Entrenamiento Pirámide (160→170→180 SPM):
├── Warmup (150 SPM)     → Canciones 145-155 BPM
├── Work Block 1 (160)   → Canciones 158-162 BPM
├── Rest (150)           → Canciones 145-155 BPM
├── Work Block 2 (170)   → Canciones 168-172 BPM
├── Rest (150)           → Canciones 145-155 BPM
├── Work Block 3 (180)   → Canciones 178-182 BPM
└── Cooldown (150)       → Canciones 145-155 BPM
```

**Implementación técnica:**

| Aspecto | Apple Music | Spotify |
|---------|-------------|---------|
| API de BPM | ✅ MusicKit `AudioFeatures` | ❌ Requiere Web API (dev account) |
| Crear playlist | ✅ `MusicLibrary.shared.add()` | ❌ Requiere OAuth |
| Disponibilidad | ✅ Ahora | ⏳ Cuando acepten nuevos devs |

**Modelo de datos propuesto:**

```swift
struct WorkoutPlaylist {
    let workoutId: UUID
    let phases: [PlaylistPhase]
    let totalDuration: TimeInterval
}

struct PlaylistPhase {
    let phase: IntervalPhase
    let targetCadence: Int          // SPM objetivo
    let bpmRange: ClosedRange<Int>  // Rango BPM canciones (±5)
    let songs: [Song]
    let duration: TimeInterval
}

struct Song {
    let id: String
    let title: String
    let artist: String
    let bpm: Int                    // Tempo de la canción
    let duration: TimeInterval
    let serviceType: MusicServiceType
}
```

**Algoritmo de selección:**

```swift
class PlaylistGenerator {
    /// Genera playlist óptima para un entrenamiento
    func generatePlaylist(
        for plan: TrainingPlan,
        from library: [Song]
    ) -> WorkoutPlaylist {
        var phases: [PlaylistPhase] = []

        for block in plan.allPhases {
            let targetBPM = block.targetCadence
            let tolerance = 5

            // Filtrar canciones por BPM
            let matchingSongs = library.filter { song in
                (targetBPM - tolerance)...(targetBPM + tolerance)
                    .contains(song.bpm)
            }

            // Seleccionar canciones para cubrir duración
            let selectedSongs = selectSongs(
                from: matchingSongs,
                toFill: block.duration
            )

            phases.append(PlaylistPhase(
                phase: block.phase,
                targetCadence: targetBPM,
                bpmRange: (targetBPM - tolerance)...(targetBPM + tolerance),
                songs: selectedSongs,
                duration: block.duration
            ))
        }

        return WorkoutPlaylist(phases: phases)
    }

    /// Selecciona canciones para llenar una duración
    private func selectSongs(
        from songs: [Song],
        toFill duration: TimeInterval
    ) -> [Song] {
        var selected: [Song] = []
        var remaining = duration
        var shuffled = songs.shuffled()

        while remaining > 0 && !shuffled.isEmpty {
            let song = shuffled.removeFirst()
            selected.append(song)
            remaining -= song.duration
        }

        return selected
    }
}
```

**UI propuesta:**

```
┌─────────────────────────────────────────┐
│  Crear Playlist para Entrenamiento      │
├─────────────────────────────────────────┤
│  Plan: Pirámide 160-170-180             │
│  Duración: 46 min                       │
│                                         │
│  📚 Fuente: [Mi Playlist Running ▼]     │
│                                         │
│  Análisis de canciones:                 │
│  ├── 145-155 BPM: 12 canciones ✅       │
│  ├── 158-162 BPM: 8 canciones ✅        │
│  ├── 168-172 BPM: 5 canciones ⚠️        │
│  └── 178-182 BPM: 3 canciones ⚠️        │
│                                         │
│  ⚠️ Faltan canciones para 170-180 BPM   │
│     Añade más música rápida             │
│                                         │
│  [Generar Playlist]                     │
└─────────────────────────────────────────┘
```

**Fases de desarrollo:**

| Fase | Descripción | Dependencia |
|------|-------------|-------------|
| F1.1 | Modelo de datos y algoritmo | Ninguna |
| F1.2 | Integración Apple Music (MusicKit) | Cuenta dev de pago |
| F1.3 | UI de generación de playlist | F1.1 |
| F1.4 | Sincronización playlist ↔ entrenamiento | F1.2, F1.3 |
| F1.5 | Integración Spotify (si disponible) | Spotify dev account |

**Notas:**
- Apple Music es la opción más viable ahora (MusicKit incluido en iOS)
- Spotify requiere Web API con OAuth - no disponible hasta que acepten nuevos devs
- Los BPM de canciones se pueden obtener de:
  - Apple Music: `MusicCatalogSearchRequest` con `AudioFeatures`
  - Spotify: `/audio-features/{id}` endpoint (requiere auth)
  - Alternativa: Base de datos externa como Beatport/Tunebat API

---

### F2: Otras Funcionalidades Futuras

| Feature | Descripción | Prioridad |
|---------|-------------|-----------|
| **Strava Export** | Exportar entrenamientos a Strava | Media |
| **Apple Watch** | App companion para watchOS | Media |
| **Widgets** | Widget de iOS con próximo entreno | Baja |
| **Social** | Compartir entrenamientos | Baja |
| **AI Coach** | Sugerencias de planes personalizados | Baja |

---

## Changelog

| Fecha | Cambios |
|-------|---------|
| 2026-01-27 | Plan inicial |
| 2026-01-28 | M1 completado: Timer, audio, UI básica |
| 2026-01-29 | Progressive workouts, navegación |
| 2026-01-30 | Music widget, Spotify detection |
| 2026-01-31 | **Refactor mayor**: Cadencia vs FC clarificado, HealthKit eliminado, SDKs externos no necesarios |
| 2026-01-31 | Añadida F1: Playlist Inteligente por Cadencia |

---

*Última actualización: 2026-01-31*
