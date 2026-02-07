# PLAN.md - IntervalPro Development Plan

## Overview

**Project:** IntervalPro iOS
**Developer Account:** Free (no HealthKit, no App Store until upgrade)
**iOS Target:** 16.0+
**Bundle ID:** com.jbd.intervalpro.app
**Last Updated:** 6 Febrero 2026
**Completion:** ~70%

---

## Current Status Summary

```
================================================================================
                        PROJECT COMPLETION: 70%
================================================================================

[##########################################################....................]

Core Training      [████████████████████] 100%
HR Monitoring      [████████████████████] 100%
Audio/Metronome    [████████████████████] 100%
Music Integration  [████████████████████] 100%
Persistence        [████████████████████] 100%
Training UI        [████████████████████] 100%
Progress Dashboard [████████████████████] 100%
Walking Workouts   [████████████████████] 100%
Coaching           [████████████████████] 100%
Plan Creation UI   [                    ]   0%
Export Features    [                    ]   0%
Advanced Analytics [                    ]   0%
================================================================================
```

---

## Key Clarifications

### Cadence vs Heart Rate

**IMPORTANTE:** Los valores BPM (150, 160, 170, 180) son **CADENCIA** (pasos por minuto), NO frecuencia cardíaca.

| Métrica | Unidad | Fuente | Uso |
|---------|--------|--------|-----|
| **Cadencia** | SPM (pasos/min) | Garmin RSC (0x1814) / iPhone Pedometer | Tracking de zonas, metrónomo |
| **FC** | lpm (latidos/min) | Garmin HR (0x180D) | Solo mostrar (informativo) |

### SDKs Externos

**NO se requiere ningún SDK externo:**

| SDK | Estado | Motivo |
|-----|--------|--------|
| Garmin Connect IQ | ❌ No necesario | CoreBluetooth estándar funciona |
| Spotify SDK | ❌ No necesario | MPNowPlayingInfoCenter + URL schemes |
| HealthKit | ⏳ Opcional | Requiere cuenta de pago ($99/año) |
| Firebase | ⏳ Opcional | Para analytics, se puede añadir después |

---

## Milestones

| Milestone | Estado | Descripción |
|-----------|--------|-------------|
| **M1: MVP Timer** | ✅ COMPLETO | Timer, simulación, metrónomo, UI básica |
| **M2: Garmin BLE** | ✅ COMPLETO | Conexión BLE real, HR + RSC services |
| **M3: Audio Completo** | ✅ COMPLETO | Metrónomo, voz, music overlay |
| **M4: Persistencia** | ✅ COMPLETO | CoreData sessions, progress dashboard |
| **M5: Walking Workouts** | ✅ COMPLETO | UI específica caminata, pasos |
| **M6: Coaching** | ✅ COMPLETO | Instrucciones voz, zona tracking |
| **M7: Plan Creation UI** | ⏳ PENDIENTE | UI para crear planes custom |
| **M8: Export** | ⏳ PENDIENTE | GPX/TCX, Strava |
| **M9: Analytics** | ⏳ PENDIENTE | Charts, tendencias |
| **M10: App Store** | ⏳ PENDIENTE | Requiere cuenta de pago |

---

## Detailed Task Status

### ✅ COMPLETADO (70%)

#### Core Training Engine
- [x] IntervalTimer con CADisplayLink (30-60 FPS)
- [x] Fases: warmup, work, rest, cooldown
- [x] Planes progresivos (pirámide 160→170→180 SPM)
- [x] Control de series y bloques (WorkBlock)
- [x] Skip de fases (warmup, cooldown, fase actual)
- [x] Ajuste de tiempo (+/- segundos)
- [x] Avisos de tiempo (30, 10, 5, 3, 2, 1 segundos)
- [x] 5 planes predefinidos (Recomendado, Principiante, Intermedio, Avanzado, Caminata)

#### Heart Rate Monitoring
- [x] GarminManager con CoreBluetooth estándar
- [x] HR Service (0x180D) para frecuencia cardíaca
- [x] RSC Service (0x1814) para cadencia/velocidad
- [x] Auto-reconnect con backoff exponencial (3 intentos, 2s base)
- [x] Deep scan mode para discovery
- [x] Device ID persistence (UserDefaults)
- [x] Fallback a HealthKit cuando Garmin no disponible
- [x] PedometerService para cadencia iPhone (CMPedometer)
- [x] HRDataService unificado (Garmin > HealthKit > iPhone)
- [x] Filtrado de outliers HR (ventana de 5 valores)
- [x] Modo simulación para testing

#### Audio
- [x] MetronomeEngine con AVAudioSession
- [x] Mixing con música (.mixWithOthers)
- [x] Ducking durante anuncios (.duckOthers)
- [x] Sonidos: click, beep, woodblock
- [x] BPM configurable (150-190)
- [x] Control de volumen independiente (metrónomo vs voz)
- [x] AVSpeechSynthesizer para anuncios
- [x] Mensajes en español

#### Music Integration
- [x] UnifiedMusicController con detección automática
- [x] Apple Music: control completo (play/pause/skip)
- [x] Spotify: lectura de estado (MPNowPlayingInfoCenter)
- [x] MiniPlayerView con artwork y controles
- [x] VolumeControlSheet (long press)

#### Persistence
- [x] CoreData con encriptación (AES-256)
- [x] TrainingSessionEntity con mapping
- [x] IntervalRecord con muestras HR
- [x] SessionRepository con CRUD async/await
- [x] Fetch: por ID, recientes, por plan, mejor sesión
- [x] Guardado de sesiones parciales (detenidas)

#### Training UI
- [x] TrainingView con layout adaptativo
- [x] Timer display con fase y tiempo restante
- [x] Cadence display con barra de zona
- [x] Pace display con comparación vs mejor sesión
- [x] Métricas: pace, distancia, pasos
- [x] Indicador de progreso de series (dots)
- [x] Controles: pause, stop, volume, skip
- [x] Widget de música integrado
- [x] Gradiente de fondo según fase

#### Walking Workouts
- [x] WalkingPaceDisplay prominente
- [x] PaceZoneBar visual
- [x] WalkingMetricsRow: pace, distancia, pasos
- [x] Detección automática tipo entreno (isWalkingWorkout)
- [x] Contador de pasos por sesión (no acumulado)

#### Progress Dashboard
- [x] Lista de sesiones recientes (últimas 50)
- [x] SessionRowView con resumen
- [x] SessionDetailView con score circle
- [x] Tarjetas de resumen (duración, distancia, pace)
- [x] Gráfico de intervalos
- [x] Grid de estadísticas
- [x] Empty state para usuarios nuevos

#### Coaching
- [x] CoachingService con análisis cadencia + pace
- [x] Estados: maintain, speed up/down cadence/pace
- [x] Mensajes en español
- [x] Throttling de anuncios (15 segundos mínimo)

#### Infrastructure
- [x] Estructura de proyecto Xcode
- [x] SwiftLint configurado
- [x] 11 archivos de tests unitarios
- [x] Onboarding flow con permisos
- [x] GarminPairingView con discovery
- [x] ProfileView con ajustes
- [x] Logging estructurado (os.Logger)

---

### ⏳ PENDIENTE (30%)

#### Prioridad ALTA - Plan Creation UI
- [ ] Pantalla de creación de plan
  - [ ] Selector de zona de trabajo (160/170/180 SPM)
  - [ ] Slider de duración trabajo (1-10 min)
  - [ ] Selector de zona de descanso
  - [ ] Control de número de series (2-20)
  - [ ] Toggles warmup/cooldown
  - [ ] Preview de tiempo total
  - [ ] Guardar plan con nombre
- [ ] Editar planes existentes
- [ ] Eliminar planes
- [ ] Límite de planes (10 free, ilimitado premium)

**Estimación:** 2-3 días

#### Prioridad MEDIA - Export Features
- [ ] Export GPX
- [ ] Export TCX
- [ ] Integración Strava
- [ ] Share cards para redes sociales
- [ ] HealthKit workout write

**Estimación:** 3-4 días

#### Prioridad MEDIA - Advanced Analytics
- [ ] Gráfico de tendencia de scores (Swift Charts)
- [ ] Gráfico de tiempo en zona semanal
- [ ] Records personales (best pace, best score, streak)
- [ ] Estadísticas semanales/mensuales
- [ ] TRIMP (Training Impulse)

**Estimación:** 3-4 días

#### Prioridad BAJA - Future Features
- [ ] Sistema Premium/Suscripción (StoreKit 2)
- [ ] Cloud Sync (CloudKit)
- [ ] Apple Watch Companion (watchOS)
- [ ] Features Sociales (challenges, leaderboards)
- [ ] Playlist Inteligente por Cadencia

---

### ❌ ELIMINADO/POSPUESTO

- [-] HealthKit obligatorio (opcional con cuenta de pago)
- [-] Spotify SDK OAuth (no acepta nuevos devs)
- [-] Garmin Connect IQ SDK (CoreBluetooth funciona)
- [-] Firebase Analytics (pospuesto)

---

## Arquitectura Actual

```
┌─────────────────────────────────────────────────────────┐
│                    IntervalPro App                       │
├─────────────────────────────────────────────────────────┤
│  TrainingView                                            │
│  ├── Cadencia Display (SPM) + Zone Bar                  │
│  ├── FC Display (lpm) - solo informativo                │
│  ├── Timer + Phase Indicator                            │
│  ├── Pace + Distance + Steps                            │
│  └── Music Widget (read-only for Spotify)               │
├─────────────────────────────────────────────────────────┤
│  TrainingViewModel (733 líneas)                         │
│  ├── Timer control (IntervalTimer)                      │
│  ├── HR/Cadence bindings (HRDataService)               │
│  ├── Audio coordination (MetronomeEngine)              │
│  ├── Session recording                                  │
│  └── Best session comparison                            │
├─────────────────────────────────────────────────────────┤
│  HRDataService (Unified Data)                           │
│  ├── Cadence → Zone Status (tracking)                   │
│  ├── Heart Rate → Display only                          │
│  ├── Pace, Speed, Distance, Steps                       │
│  └── Source: Garmin > HealthKit > iPhone > Simulation   │
├─────────────────────────────────────────────────────────┤
│  GarminManager (CoreBluetooth)                          │
│  ├── HR Service (0x180D) → FC                           │
│  ├── RSC Service (0x1814) → Cadencia, Velocidad         │
│  └── Auto-reconnect con backoff                         │
├─────────────────────────────────────────────────────────┤
│  CoreData (Local Storage + Encryption)                  │
│  ├── TrainingSessionEntity                              │
│  ├── IntervalRecord (JSON encoded)                      │
│  └── SessionRepository (async/await)                    │
└─────────────────────────────────────────────────────────┘
```

---

## File Structure

```
IntervalPro/                          (~10,000 líneas total)
├── App/                              (4 archivos)
│   ├── IntervalProApp.swift          # Entry point
│   ├── AppState.swift                # Global state
│   ├── ContentView.swift             # TabView, Home, Progress, Profile
│   └── NavigationRouter.swift        # Routing
│
├── Features/
│   ├── Training/
│   │   ├── Models/                   (4 archivos)
│   │   │   ├── TrainingPlan.swift    # 329 líneas
│   │   │   ├── TrainingSession.swift
│   │   │   ├── HeartRateZone.swift   # 389 líneas
│   │   │   └── IntervalPhase.swift
│   │   ├── ViewModels/               (1 archivo)
│   │   │   └── TrainingViewModel.swift # 733 líneas
│   │   └── Views/                    (4 archivos)
│   │       ├── TrainingView.swift
│   │       ├── TrainingViewComponents.swift
│   │       ├── WalkingWorkoutViews.swift
│   │       └── MiniPlayerView.swift
│   └── Settings/Views/              (2 archivos)
│       ├── GarminPairingView.swift
│       └── HealthKitPermissionView.swift
│
├── Core/
│   ├── Timer/
│   │   └── IntervalTimer.swift       # 375 líneas
│   ├── Health/
│   │   ├── HRDataService.swift
│   │   └── HealthKitManager.swift
│   ├── Bluetooth/
│   │   └── GarminManager.swift
│   ├── Audio/
│   │   ├── MetronomeEngine.swift
│   │   └── UnifiedMusicController.swift
│   ├── Motion/
│   │   └── PedometerService.swift
│   ├── Training/
│   │   └── CoachingService.swift
│   └── Persistence/
│       ├── CoreDataStack.swift
│       ├── SessionRepository.swift
│       └── Entities/
│           └── TrainingSessionEntity.swift
│
├── Shared/
│   ├── Components/DesignTokens.swift
│   ├── Extensions/TimeInterval+Formatting.swift
│   └── Utilities/Logger.swift
│
└── Tests/UnitTests/                  (11 archivos)
    ├── TrainingViewModelTests.swift
    ├── IntervalTimerTests.swift
    ├── MetronomeEngineTests.swift
    └── ... (8 more)
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
| Datos erráticos | Normal los primeros segundos, se estabiliza |

---

## Próximos Pasos Inmediatos

### Esta Semana
1. [ ] Testing en dispositivo real (iPhone + Garmin)
2. [ ] Verificar guardado y visualización de sesiones
3. [ ] Fix de bugs encontrados en testing

### Próximas 2 Semanas
1. [ ] UI de creación de planes personalizados
2. [ ] Mejoras de UX basadas en testing
3. [ ] Preparación para TestFlight beta

### Antes de Lanzamiento
1. [ ] Exportación GPX/TCX
2. [ ] Analytics avanzado con Swift Charts
3. [ ] Polish de UI y animaciones
4. [ ] Localización completa (es/en)
5. [ ] Upgrade a cuenta de pago ($99)
6. [ ] App Store submission

---

## Recent Commits

| Fecha | Commit | Descripción |
|-------|--------|-------------|
| 2026-02-06 | 8afa38a | Fix: sesiones no aparecían en progreso |
| 2026-02-05 | 6915495 | Walking workouts UI y mejoras |
| 2026-02-04 | 58c8640 | Integración sensores iPhone sin Garmin |
| 2026-02-03 | 4f3c56e | Modo simulación y widgets |
| 2026-02-02 | e7e6db5 | Plan caminata 50 minutos |

---

## Known Issues

| Issue | Estado | Descripción |
|-------|--------|-------------|
| #1 | ✅ RESUELTO | Sesiones no aparecían en progreso (fix: 8afa38a) |
| #2 | ⏳ PENDIENTE | Testing en dispositivo real necesario |
| #3 | ⏳ PENDIENTE | Verificar overlay audio con Spotify |

---

## Costes y Requisitos

| Requisito | Coste | Estado |
|-----------|-------|--------|
| Mac con Xcode | $0 | ✅ Disponible |
| iPhone para testing | $0 | ✅ Disponible |
| Garmin Fenix | $0 | ✅ Disponible |
| Apple Developer (free) | $0 | ✅ Activo |
| Apple Developer (paid) | $99/año | ⏳ Para App Store |

---

## Changelog

| Fecha | Cambios |
|-------|---------|
| 2026-01-27 | Plan inicial |
| 2026-01-28 | M1 completado: Timer, audio, UI básica |
| 2026-01-29 | Progressive workouts, navegación |
| 2026-01-30 | Music widget, Spotify detection |
| 2026-01-31 | Refactor: Cadencia vs FC clarificado |
| 2026-02-01 | Garmin BLE completado |
| 2026-02-02 | Walking workouts |
| 2026-02-04 | Sensores iPhone (pedometer) |
| 2026-02-05 | Progress dashboard, session detail |
| 2026-02-06 | **Fix bug sesiones, documentación actualizada** |

---

*Última actualización: 2026-02-06*
