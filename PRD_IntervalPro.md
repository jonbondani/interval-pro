# Product Requirements Document (PRD)
## IntervalPro - iOS Running Interval Training App

**Versión:** 1.0
**Fecha:** 27 de Enero, 2026
**Autor:** Product Team
**Estado:** Draft

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Definición del Problema](#2-definición-del-problema)
3. [Objetivos del Producto](#3-objetivos-del-producto)
4. [Público Objetivo](#4-público-objetivo)
5. [User Stories](#5-user-stories)
6. [Requisitos Funcionales](#6-requisitos-funcionales)
7. [Especificaciones Técnicas](#7-especificaciones-técnicas)
8. [Wireframes Textuales](#8-wireframes-textuales)
9. [Métricas de Éxito](#9-métricas-de-éxito)
10. [Riesgos y Mitigaciones](#10-riesgos-y-mitigaciones)
11. [Dependencias Técnicas](#11-dependencias-técnicas)
12. [Roadmap](#12-roadmap)
13. [Apéndices](#13-apéndices)

---

## 1. Resumen Ejecutivo

**IntervalPro** es una aplicación iOS diseñada para corredores que buscan optimizar su entrenamiento mediante intervalos HIIT basados en zonas de frecuencia cardíaca. La app se integra nativamente con dispositivos Garmin Fenix y utiliza un sistema de metrónomo audible que funciona en overlay con servicios de streaming musical, permitiendo entrenamientos más efectivos y medibles.

### Propuesta de Valor Única

- **Entrenamiento basado en FC real-time** con zonas precisas (150-180 BPM)
- **Integración nativa Garmin Fenix** via Bluetooth/HealthKit
- **Metrónomo audible overlay** compatible con Spotify/Apple Music
- **Análisis histórico inteligente** para igualar/superar mejores sesiones
- **AutoLap automático** sincronizado con fases de trabajo/descanso

---

## 2. Definición del Problema

### 2.1 Contexto del Problema

Los corredores que realizan entrenamientos de intervalos HIIT enfrentan múltiples desafíos:

| Problema | Impacto | Frecuencia |
|----------|---------|------------|
| Dificultad para mantener zonas de FC específicas | Entrenamientos subóptimos, riesgo de sobreentrenamiento | 85% usuarios |
| Falta de feedback en tiempo real | No ajustan intensidad correctamente | 78% usuarios |
| Apps de música vs. apps de entrenamiento separadas | Experiencia fragmentada, interrupciones | 92% usuarios |
| Sin referencia histórica de rendimiento | No hay progresión medible | 70% usuarios |
| Configuración manual de intervalos en reloj | Fricción, errores de configuración | 65% usuarios |

### 2.2 Estado Actual del Mercado

```
┌─────────────────────────────────────────────────────────────────┐
│                    ANÁLISIS COMPETITIVO                         │
├─────────────────────┬───────────┬───────────┬───────────────────┤
│ Feature             │ Garmin    │ Strava    │ IntervalPro       │
│                     │ Connect   │ Premium   │ (Propuesto)       │
├─────────────────────┼───────────┼───────────┼───────────────────┤
│ Intervalos FC-based │ Parcial   │ No        │ ✓ Completo        │
│ Metrónomo overlay   │ No        │ No        │ ✓ Sí              │
│ Análisis histórico  │ Básico    │ Avanzado  │ ✓ Inteligente     │
│ AutoLap dinámico    │ Manual    │ No        │ ✓ Automático      │
│ Integración música  │ No        │ No        │ ✓ Spotify/AM      │
└─────────────────────┴───────────┴───────────┴───────────────────┘
```

### 2.3 Hipótesis

> Si proporcionamos a los corredores una herramienta que combine entrenamiento por intervalos basado en FC con feedback auditivo integrado con su música favorita, entonces aumentarán su adherencia al entrenamiento y mejorarán su rendimiento de manera medible.

---

## 3. Objetivos del Producto

### 3.1 Objetivos de Negocio

| Objetivo | Métrica | Target Q1 | Target Q4 |
|----------|---------|-----------|-----------|
| Adquisición usuarios | MAU | 10,000 | 50,000 |
| Retención | D30 Retention | 60% | 80% |
| Engagement | Sessions/week/user | 2.5 | 4.0 |
| Monetización | Conversión Premium | 5% | 12% |

### 3.2 Objetivos de Usuario

1. **Eficiencia**: Reducir tiempo de configuración de entrenamientos en 80%
2. **Efectividad**: Aumentar % de tiempo en zona objetivo de FC en 40%
3. **Progresión**: Visibilidad clara de mejora en rendimiento semana a semana
4. **Experiencia**: Mantener flujo musical sin interrupciones durante entrenamiento

### 3.3 OKRs

```
OBJETIVO 1: Crear la mejor experiencia de entrenamiento por intervalos
├── KR1: 80% usuarios completan sesión sin abandonar
├── KR2: NPS > 50 en primeros 90 días
└── KR3: 4.5+ rating en App Store

OBJETIVO 2: Maximizar integración con ecosistema runner
├── KR1: 70% usuarios conectan Garmin en primera semana
├── KR2: 60% usuarios activan metrónomo con música
└── KR3: 90% precisión en datos FC vs. Garmin nativo
```

---

## 4. Público Objetivo

### 4.1 Persona Principal: "Carlos - El Corredor Comprometido"

```
┌────────────────────────────────────────────────────────────────┐
│  PERSONA: Carlos                                                │
├────────────────────────────────────────────────────────────────┤
│  Edad: 32-45 años                                              │
│  Ocupación: Profesional urbano                                 │
│  Experiencia running: 2-5 años                                 │
│  Dispositivo: iPhone 13+ / Garmin Fenix 6/7                    │
│  Objetivo: Mejorar marca en media maratón                      │
├────────────────────────────────────────────────────────────────┤
│  COMPORTAMIENTOS:                                              │
│  • Entrena 4-5 veces/semana                                    │
│  • Usa Spotify durante entrenamientos                          │
│  • Revisa métricas post-entrenamiento                          │
│  • Comparte logros en redes sociales                           │
├────────────────────────────────────────────────────────────────┤
│  FRUSTRACIONES:                                                │
│  • "Tengo que pausar la música para escuchar alertas"          │
│  • "No sé si estoy mejorando realmente"                        │
│  • "Configurar intervalos en Garmin es tedioso"                │
├────────────────────────────────────────────────────────────────┤
│  MOTIVACIONES:                                                 │
│  • Batir récords personales                                    │
│  • Entrenar de forma inteligente, no solo dura                 │
│  • Tener datos para optimizar rendimiento                      │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Persona Secundaria: "María - La Entrenadora Personal"

- **Edad:** 28-40 años
- **Rol:** Entrenadora certificada con clientes runners
- **Necesidad:** Crear y asignar planes a múltiples atletas
- **Feature clave:** Export de sesiones y análisis comparativo

---

## 5. User Stories

### 5.1 Epic 1: Configuración de Planes de Intervalos

| ID | User Story | Criterios de Aceptación | Prioridad |
|----|------------|------------------------|-----------|
| US-101 | Como corredor, quiero configurar intervalos por zonas de BPM para entrenar en la intensidad correcta | - Selección de zona trabajo: 160/170/180 BPM<br>- Selección zona descanso: 150 BPM<br>- Duración configurable (default 3 min)<br>- Validación de rangos | P0 |
| US-102 | Como corredor, quiero definir el número de series para adaptar el entrenamiento a mi nivel | - Mínimo 2 series<br>- Máximo 20 series<br>- Incrementos de 1<br>- Tiempo total estimado visible | P0 |
| US-103 | Como corredor, quiero guardar planes personalizados para reutilizarlos | - Nombre personalizado<br>- Hasta 10 planes guardados (free)<br>- Ilimitados (premium)<br>- Edición y eliminación | P1 |
| US-104 | Como corredor, quiero planes predefinidos para empezar rápidamente | - 3 planes: Principiante, Intermedio, Avanzado<br>- Descripción de cada plan<br>- Quick start en 1 tap | P1 |

### 5.2 Epic 2: Integración Garmin Fenix

| ID | User Story | Criterios de Aceptación | Prioridad |
|----|------------|------------------------|-----------|
| US-201 | Como usuario de Garmin, quiero conectar mi Fenix para obtener datos precisos | - Pairing via Bluetooth LE<br>- Fallback a HealthKit<br>- Estado de conexión visible<br>- Reconexión automática | P0 |
| US-202 | Como corredor, quiero ver mi FC en tiempo real durante el entrenamiento | - Actualización cada 1 segundo<br>- Display prominente (font 48pt+)<br>- Color según zona (verde/amarillo/rojo)<br>- Alerta vibración fuera de zona | P0 |
| US-203 | Como corredor, quiero ver velocidad y ritmo en tiempo real | - Pace actual (min/km)<br>- Velocidad (km/h)<br>- Pace promedio del intervalo<br>- Distancia acumulada | P0 |
| US-204 | Como corredor, quiero AutoLap automático al cambiar de fase | - Lap automático al iniciar trabajo<br>- Lap automático al iniciar descanso<br>- Sincronización con Garmin<br>- Historial de laps visible | P0 |

### 5.3 Epic 3: Metrónomo y Audio

| ID | User Story | Criterios de Aceptación | Prioridad |
|----|------------|------------------------|-----------|
| US-301 | Como corredor, quiero un metrónomo que suene sobre mi música para mantener cadencia | - BPM configurable (150-190)<br>- Volumen independiente<br>- No interrumpe Spotify/Apple Music<br>- Sonido click/beep seleccionable | P0 |
| US-302 | Como corredor, quiero alertas de voz sobre el estado del entrenamiento | - "Iniciando trabajo" / "Iniciando descanso"<br>- "30 segundos restantes"<br>- "Sube/baja intensidad" según FC<br>- Voz en español/inglés | P0 |
| US-303 | Como corredor, quiero controlar mi música desde la app | - Play/Pause/Skip<br>- Volumen música vs. metrónomo<br>- Visualización canción actual<br>- Integración Spotify + Apple Music | P1 |

### 5.4 Epic 4: Análisis y Progresión

| ID | User Story | Criterios de Aceptación | Prioridad |
|----|------------|------------------------|-----------|
| US-401 | Como corredor, quiero ver mi mejor sesión para intentar igualarla/superarla | - "Best session" por tipo de plan<br>- Comparativa en tiempo real<br>- Indicador +/- vs. mejor<br>- Celebración al superar récord | P0 |
| US-402 | Como corredor, quiero ver mi historial de entrenamientos | - Lista cronológica<br>- Filtros por tipo de plan<br>- Gráfico de progresión semanal<br>- Estadísticas agregadas | P1 |
| US-403 | Como corredor, quiero exportar y compartir mis sesiones | - Export a Strava<br>- Share card para redes<br>- Export GPX/TCX<br>- Integración HealthKit write | P1 |

### 5.5 Epic 5: Tracking en Vivo

| ID | User Story | Criterios de Aceptación | Prioridad |
|----|------------|------------------------|-----------|
| US-501 | Como corredor, quiero una pantalla de entrenamiento clara y legible | - Métricas principales visibles<br>- Timer intervalo prominente<br>- Indicador serie actual/total<br>- Modo oscuro para exterior | P0 |
| US-502 | Como corredor, quiero pausar/reanudar sin perder datos | - Botón pausa accesible<br>- Datos preservados<br>- Timer pausado<br>- Confirmación para finalizar | P0 |

---

## 6. Requisitos Funcionales

### 6.1 Módulo: Configuración de Planes

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONFIGURACIÓN DE INTERVALOS                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TRABAJO (Work Phase)                                           │
│  ├── Zona FC Target: [160] [170] [180] BPM                     │
│  ├── Duración: [3] minutos (1-10 min)                          │
│  └── Tolerancia: ±5 BPM                                        │
│                                                                 │
│  DESCANSO (Rest Phase)                                          │
│  ├── Zona FC Target: [150] BPM                                 │
│  ├── Duración: [3] minutos (1-10 min)                          │
│  └── Recuperación mínima: 70% de FC max                        │
│                                                                 │
│  SERIES                                                         │
│  ├── Cantidad: [4] series (2-20)                               │
│  ├── Warm-up: [5] min (opcional)                               │
│  └── Cool-down: [5] min (opcional)                             │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│  Tiempo Total Estimado: 34 minutos                             │
│  Calorías Estimadas: 420 kcal                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Módulo: Tracking Real-Time

#### 6.2.1 Datos Capturados

| Dato | Fuente | Frecuencia | Almacenamiento |
|------|--------|------------|----------------|
| Frecuencia Cardíaca | Garmin/HealthKit | 1 Hz | Local + Cloud |
| Velocidad | Garmin GPS | 1 Hz | Local + Cloud |
| Ritmo (Pace) | Calculado | 1 Hz | Local + Cloud |
| Distancia | Garmin GPS | 1 Hz | Local + Cloud |
| Cadencia | Garmin/Acelerómetro | 1 Hz | Local |
| Ubicación GPS | Garmin/CoreLocation | 1 Hz | Local (GPX) |

#### 6.2.2 Lógica AutoLap

```swift
// Pseudocódigo lógica AutoLap
enum IntervalPhase {
    case warmup
    case work
    case rest
    case cooldown
}

func onPhaseChange(from: IntervalPhase, to: IntervalPhase) {
    // 1. Marcar lap en sesión local
    currentSession.addLap(
        phase: from,
        duration: phaseDuration,
        avgHR: phaseAvgHR,
        distance: phaseDistance
    )

    // 2. Enviar comando AutoLap a Garmin
    garminConnection.sendLapMarker()

    // 3. Trigger audio feedback
    audioManager.announce(phase: to)

    // 4. Actualizar UI
    updatePhaseDisplay(to)
}
```

### 6.3 Módulo: Audio Overlay

#### 6.3.1 Arquitectura Audio

```
┌─────────────────────────────────────────────────────────────────┐
│                      AUDIO MIXING ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐   │
│  │   Spotify/   │     │  Metronome   │     │    Voice     │   │
│  │ Apple Music  │     │   Engine     │     │   Alerts     │   │
│  │              │     │              │     │              │   │
│  │ MPMusicPlayer│     │AVAudioPlayer │     │AVSpeech      │   │
│  │ Controller   │     │              │     │Synthesizer   │   │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘   │
│         │                    │                    │            │
│         ▼                    ▼                    ▼            │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   AVAudioSession                         │  │
│  │            Category: .playback                           │  │
│  │            Mode: .default                                │  │
│  │            Options: [.mixWithOthers, .duckOthers]       │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Audio Output                          │  │
│  │              (AirPods / Speaker / BT)                    │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 6.3.2 Configuración Metrónomo

```swift
struct MetronomeConfig {
    var bpm: Int              // 150-190
    var volume: Float         // 0.0-1.0
    var soundType: SoundType  // .click, .beep, .woodblock
    var enabled: Bool
    var syncToMusic: Bool     // Attempt BPM matching
}

enum SoundType {
    case click      // Subtle, low-profile
    case beep       // Electronic, precise
    case woodblock  // Natural, warm
}
```

### 6.4 Módulo: Análisis Histórico

#### 6.4.1 Algoritmo "Best Session Match"

```
┌─────────────────────────────────────────────────────────────────┐
│              BEST SESSION MATCHING ALGORITHM                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INPUT:                                                         │
│  ├── Plan Configuration (zones, duration, series)              │
│  ├── Historical Sessions (filtered by similar config)          │
│  └── Current Session Progress                                   │
│                                                                 │
│  MATCHING CRITERIA:                                             │
│  ├── Same target HR zones (±10 BPM tolerance)                  │
│  ├── Same number of series (±1 tolerance)                      │
│  └── Same interval duration (±30s tolerance)                   │
│                                                                 │
│  SCORING (Best Session = Highest Score):                       │
│  │                                                              │
│  │  Score = (0.4 × TimeInZone%) +                              │
│  │          (0.3 × AvgPace) +                                  │
│  │          (0.2 × CompletionRate) +                           │
│  │          (0.1 × TotalDistance)                              │
│  │                                                              │
│  OUTPUT:                                                        │
│  ├── Best Session Reference                                    │
│  ├── Real-time Delta (+/- metrics)                             │
│  └── Projected Final Score                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 6.4.2 Métricas de Progresión

| Métrica | Cálculo | Visualización |
|---------|---------|---------------|
| Time in Zone | % tiempo en zona target | Barra progreso + % |
| Avg Pace Trend | Media móvil 4 semanas | Gráfico línea |
| Recovery Rate | Tiempo para bajar a 150 BPM | Segundos + trend |
| Consistency Score | Desviación estándar FC | 0-100 score |
| Volume Load | Distancia × Intensidad | TRIMP points |

---

## 7. Especificaciones Técnicas

### 7.1 Stack Tecnológico

```
┌─────────────────────────────────────────────────────────────────┐
│                      TECH STACK                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FRONTEND                                                       │
│  ├── SwiftUI (iOS 16+)                                         │
│  ├── Combine (Reactive)                                        │
│  └── Swift Charts (Visualizations)                             │
│                                                                 │
│  FRAMEWORKS APPLE                                               │
│  ├── HealthKit (HR, Workouts)                                  │
│  ├── CoreBluetooth (Garmin Direct)                             │
│  ├── CoreLocation (GPS Backup)                                 │
│  ├── AVFoundation (Audio)                                      │
│  ├── MediaPlayer (Music Control)                               │
│  └── BackgroundTasks (Session Continuity)                      │
│                                                                 │
│  THIRD-PARTY                                                    │
│  ├── Garmin Connect IQ SDK                                     │
│  ├── Spotify iOS SDK (Premium users)                           │
│  └── Firebase (Analytics, Crashlytics)                         │
│                                                                 │
│  BACKEND (Future)                                               │
│  ├── CloudKit (Sync)                                           │
│  └── App Store Server API (Subscriptions)                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Arquitectura de Datos

```swift
// Core Data Models

struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    var name: String
    var workZone: HeartRateZone
    var restZone: HeartRateZone
    var workDuration: TimeInterval  // seconds
    var restDuration: TimeInterval
    var seriesCount: Int
    var warmupDuration: TimeInterval?
    var cooldownDuration: TimeInterval?
    var createdAt: Date
    var isDefault: Bool
}

struct HeartRateZone: Codable {
    var targetBPM: Int          // 150, 160, 170, 180
    var toleranceBPM: Int       // default: 5
    var minBPM: Int { targetBPM - toleranceBPM }
    var maxBPM: Int { targetBPM + toleranceBPM }
}

struct TrainingSession: Identifiable, Codable {
    let id: UUID
    let planId: UUID
    let startDate: Date
    var endDate: Date?
    var intervals: [IntervalRecord]
    var isCompleted: Bool
    var totalDistance: Double   // meters
    var avgHeartRate: Int
    var maxHeartRate: Int
    var timeInZone: TimeInterval
    var score: Double           // calculated
}

struct IntervalRecord: Identifiable, Codable {
    let id: UUID
    var phase: IntervalPhase
    var startTime: TimeInterval // offset from session start
    var duration: TimeInterval
    var avgHR: Int
    var maxHR: Int
    var minHR: Int
    var distance: Double
    var avgPace: Double         // sec/km
    var hrSamples: [HRSample]
}

struct HRSample: Codable {
    let timestamp: TimeInterval
    let bpm: Int
    let source: DataSource      // .garmin, .healthkit, .watch
}
```

### 7.3 Integración Garmin

```swift
// Garmin Connection Manager

class GarminManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentHR: Int = 0
    @Published var currentPace: Double = 0
    @Published var currentSpeed: Double = 0

    private var centralManager: CBCentralManager?
    private var garminPeripheral: CBPeripheral?

    // Heart Rate Service UUID
    let hrServiceUUID = CBUUID(string: "180D")
    let hrCharacteristicUUID = CBUUID(string: "2A37")

    // Garmin-specific Running Dynamics
    let garminServiceUUID = CBUUID(string: "6A4E...")

    func connect() async throws {
        // 1. Scan for Garmin devices
        // 2. Connect to Fenix
        // 3. Discover services
        // 4. Subscribe to HR notifications
        // 5. Start receiving data
    }

    func sendLapMarker() {
        // Send lap command to Garmin
        // Triggers AutoLap on watch
    }
}
```

### 7.4 Audio Engine

```swift
// Audio Manager with Mixing

class AudioManager {
    private var audioSession: AVAudioSession
    private var metronomePlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer
    private var musicPlayer: MPMusicPlayerController

    func setupAudioSession() throws {
        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try audioSession.setActive(true)
    }

    func startMetronome(bpm: Int, volume: Float) {
        let interval = 60.0 / Double(bpm)
        // Schedule repeating audio playback
        // Use AVAudioPlayer for low-latency
    }

    func announce(_ message: String, language: String = "es-ES") {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.volume = 0.8

        // Duck music volume temporarily
        duckMusic()
        speechSynthesizer.speak(utterance)
    }
}
```

---

## 8. Wireframes Textuales

### 8.1 Pantalla Principal (Home)

```
┌─────────────────────────────────────────┐
│ ◀ IntervalPro              ⚙️ Settings │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │      🏃 QUICK START             │   │
│  │                                  │   │
│  │   [▶ Start Last Workout]        │   │
│  │   4×3min @ 170 BPM              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ── MY PLANS ─────────────────────     │
│                                         │
│  ┌───────────┐ ┌───────────┐           │
│  │ 🔥 HIIT   │ │ 💪 Tempo  │           │
│  │ 170 BPM   │ │ 160 BPM   │           │
│  │ 6 series  │ │ 4 series  │           │
│  └───────────┘ └───────────┘           │
│                                         │
│  ┌───────────┐ ┌───────────┐           │
│  │ 🚀 Speed  │ │ ➕ New    │           │
│  │ 180 BPM   │ │  Plan     │           │
│  │ 8 series  │ │           │           │
│  └───────────┘ └───────────┘           │
│                                         │
│  ── RECENT SESSIONS ──────────────     │
│                                         │
│  📅 Today      HIIT 170    ⭐ 87pts    │
│  📅 Yesterday  Tempo 160   ⭐ 92pts    │
│  📅 Mon        Speed 180   ⭐ 78pts    │
│                                         │
├─────────────────────────────────────────┤
│  🏠 Home    📊 Progress    👤 Profile  │
└─────────────────────────────────────────┘
```

### 8.2 Configuración de Plan

```
┌─────────────────────────────────────────┐
│ ◀ Back           New Plan      💾 Save │
├─────────────────────────────────────────┤
│                                         │
│  Plan Name                              │
│  ┌─────────────────────────────────┐   │
│  │ HIIT Intensivo                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ── WORK PHASE ───────────────────     │
│                                         │
│  Target Heart Rate                      │
│  ┌───────┐ ┌───────┐ ┌───────┐        │
│  │  160  │ │ [170] │ │  180  │  BPM   │
│  └───────┘ └───────┘ └───────┘        │
│                                         │
│  Duration                               │
│  ◀────────────●──────────▶  3:00 min  │
│                                         │
│  ── REST PHASE ───────────────────     │
│                                         │
│  Recovery Target                        │
│  ┌─────────────────────────────────┐   │
│  │           150 BPM               │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Duration                               │
│  ◀────────────●──────────▶  3:00 min  │
│                                         │
│  ── SERIES ───────────────────────     │
│                                         │
│         ➖    [ 4 ]    ➕              │
│                                         │
│  ☑️ Include 5 min warm-up              │
│  ☑️ Include 5 min cool-down            │
│                                         │
│  ─────────────────────────────────     │
│  📊 Total Duration: 34 min             │
│  🔥 Est. Calories: 420 kcal            │
│                                         │
├─────────────────────────────────────────┤
│         [ ▶ START WORKOUT ]            │
└─────────────────────────────────────────┘
```

### 8.3 Pantalla de Entrenamiento Activo

```
┌─────────────────────────────────────────┐
│ ⏸️ Pause                    🔊 Audio   │
├─────────────────────────────────────────┤
│                                         │
│            ┌─────────────┐              │
│            │   WORK      │              │
│            │  ███████    │  ← Phase    │
│            └─────────────┘              │
│                                         │
│              2:34                       │
│           remaining                     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │                                  │   │
│  │           ❤️ 168               │   │
│  │             BPM                  │   │
│  │                                  │   │
│  │    ▓▓▓▓▓▓▓▓▓▓▓▓░░░░            │   │
│  │    150    170    190             │   │
│  │          TARGET                  │   │
│  │                                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │  5:42    │  │  4.2     │            │
│  │  /km     │  │  km      │            │
│  │  PACE    │  │  DIST    │            │
│  └──────────┘  └──────────┘            │
│                                         │
│  ── SERIES PROGRESS ──────────────     │
│                                         │
│    ●────●────●────○────○────○          │
│    1    2    3    4    5    6          │
│              ▲                          │
│           current                       │
│                                         │
│  ── VS BEST SESSION ──────────────     │
│  │ ⬆️ +0:12 ahead  │  Zone: 94%  │    │
│                                         │
├─────────────────────────────────────────┤
│  🎵 Now Playing: "Eye of the Tiger"    │
│     ⏮️    ▶️    ⏭️      🔊────●──    │
└─────────────────────────────────────────┘
```

### 8.4 Resumen Post-Entrenamiento

```
┌─────────────────────────────────────────┐
│ ✕ Close         Session Complete    📤 │
├─────────────────────────────────────────┤
│                                         │
│            🎉 GREAT JOB!                │
│                                         │
│           ⭐ 92 points                  │
│         NEW PERSONAL BEST!              │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  📊 SESSION SUMMARY             │   │
│  ├─────────────────────────────────┤   │
│  │                                  │   │
│  │  Duration      34:22            │   │
│  │  Distance      6.8 km           │   │
│  │  Avg Pace      5:03 /km         │   │
│  │  Avg HR        165 bpm          │   │
│  │  Max HR        182 bpm          │   │
│  │  Calories      438 kcal         │   │
│  │                                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ── TIME IN ZONE ─────────────────     │
│                                         │
│  Work (170 BPM)   ▓▓▓▓▓▓▓▓░░  82%     │
│  Rest (150 BPM)   ▓▓▓▓▓▓▓▓▓░  91%     │
│                                         │
│  ── INTERVALS BREAKDOWN ──────────     │
│                                         │
│   #1  Work  168 avg  5:12/km  ✓        │
│   #1  Rest  152 avg  6:45/km  ✓        │
│   #2  Work  171 avg  5:08/km  ✓        │
│   #2  Rest  149 avg  6:52/km  ✓        │
│   ...                                   │
│                                         │
│  ── VS PREVIOUS BEST ─────────────     │
│                                         │
│  │ Time in Zone │ +4%   │ ⬆️  │       │
│  │ Avg Pace     │ -0:08 │ ⬆️  │       │
│  │ Consistency  │ +12   │ ⬆️  │       │
│                                         │
├─────────────────────────────────────────┤
│  [ Share to Strava ]  [ Save & Close ] │
└─────────────────────────────────────────┘
```

### 8.5 Pantalla de Progreso

```
┌─────────────────────────────────────────┐
│ ◀ Home            Progress      📅 ▼  │
├─────────────────────────────────────────┤
│                                         │
│  ── THIS WEEK ────────────────────     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Sessions: 4    Distance: 24km  │   │
│  │  Avg Score: 88   Time: 2h 15m   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ── SCORE TREND ──────────────────     │
│                                         │
│     100│                    ╭──        │
│      90│        ╭───╮   ╭──╯           │
│      80│   ╭────╯   ╰───╯              │
│      70│───╯                           │
│        └────────────────────────       │
│         W1   W2   W3   W4   W5         │
│                                         │
│  ── TIME IN ZONE TREND ───────────     │
│                                         │
│     100│            ▓▓▓▓               │
│      80│   ▓▓▓▓ ▓▓▓▓    ▓▓▓▓▓▓▓▓      │
│      60│▓▓▓                            │
│        └────────────────────────       │
│         W1   W2   W3   W4   W5         │
│                                         │
│  ── PERSONAL RECORDS ─────────────     │
│                                         │
│  🏆 Best Score      94 pts  (Jan 15)  │
│  🏆 Longest Streak  12 days (Jan 8)   │
│  🏆 Best Pace       4:52/km (Jan 20)  │
│                                         │
│  ── RECENT SESSIONS ──────────────     │
│                                         │
│  📅 Jan 27  HIIT 170    ⭐ 92  ▶       │
│  📅 Jan 25  Tempo 160   ⭐ 87  ▶       │
│  📅 Jan 24  HIIT 170    ⭐ 89  ▶       │
│                                         │
├─────────────────────────────────────────┤
│  🏠 Home    📊 Progress    👤 Profile  │
└─────────────────────────────────────────┘
```

---

## 9. Métricas de Éxito

### 9.1 North Star Metric

> **Weekly Active Sessions Completed (WASC)**
> Número de sesiones de entrenamiento completadas por semana por usuario activo

### 9.2 KPIs Primarios

| Categoría | Métrica | Target | Medición |
|-----------|---------|--------|----------|
| **Retención** | D1 Retention | 70% | Firebase |
| **Retención** | D7 Retention | 50% | Firebase |
| **Retención** | D30 Retention | **80%** | Firebase |
| **Engagement** | Sessions/Week | 3.5 | In-app |
| **Engagement** | Completion Rate | 85% | In-app |
| **Activation** | Garmin Connected | 70% | In-app |
| **Activation** | First Session < 24h | 60% | Firebase |

### 9.3 KPIs Secundarios

| Categoría | Métrica | Target |
|-----------|---------|--------|
| Performance | Time in Zone % | > 75% avg |
| Audio | Metronome Adoption | 50% sessions |
| Social | Share Rate | 20% sessions |
| Quality | Crash-free Rate | > 99.5% |
| Satisfaction | App Store Rating | 4.5+ stars |

### 9.4 Funnel de Activación

```
┌─────────────────────────────────────────────────────────────────┐
│                     ACTIVATION FUNNEL                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Download App                    100%  ████████████████████    │
│       │                                                         │
│       ▼                                                         │
│  Complete Onboarding              85%  ████████████████░░░░    │
│       │                                                         │
│       ▼                                                         │
│  Connect Garmin/HealthKit         70%  ██████████████░░░░░░    │
│       │                                                         │
│       ▼                                                         │
│  Create/Select First Plan         65%  █████████████░░░░░░░    │
│       │                                                         │
│       ▼                                                         │
│  Complete First Session           55%  ███████████░░░░░░░░░    │
│       │                                                         │
│       ▼                                                         │
│  Complete 3 Sessions (Week 1)     40%  ████████░░░░░░░░░░░░    │
│       │                                                         │
│       ▼                                                         │
│  Retained at Day 30               30%  ██████░░░░░░░░░░░░░░    │
│                                                                 │
│  TARGET: 80% D30 Retention from activated users                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. Riesgos y Mitigaciones

### 10.1 Matriz de Riesgos

```
                    IMPACTO
              Bajo    Medio    Alto
         ┌────────┬────────┬────────┐
    Alto │   R3   │   R2   │   R1   │
         │        │   R5   │   R4   │
P   ─────┼────────┼────────┼────────┤
R  Medio │   R7   │   R6   │   R8   │
O        │        │        │        │
B   ─────┼────────┼────────┼────────┤
.   Bajo │   R9   │  R10   │  R11   │
         │        │        │        │
         └────────┴────────┴────────┘
```

### 10.2 Detalle de Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|----|--------|-------|---------|------------|
| **R1** | **Privacy FC - Datos sensibles de salud expuestos** | Alta | Alto | - Encriptación end-to-end<br>- Cumplimiento HIPAA<br>- No almacenar datos raw en cloud<br>- Auditoría seguridad trimestral |
| **R2** | Garmin cambia API/SDK | Media | Alto | - Abstraer capa conexión<br>- Fallback HealthKit<br>- Monitorear changelog Garmin |
| **R3** | Latencia audio overlay perceptible | Alta | Bajo | - Pre-buffer audio<br>- Usar AVAudioEngine<br>- Testing extensivo dispositivos |
| **R4** | Apple rechaza app por uso HealthKit | Media | Alto | - Seguir guidelines estrictamente<br>- Justificar cada permiso<br>- Tener plan alternativo CoreMotion |
| **R5** | Spotify rate-limits integración | Media | Medio | - Implementar caching<br>- Fallback Apple Music<br>- User education |
| **R6** | Baja adopción metrónomo | Media | Medio | - A/B test onboarding<br>- Tutorial interactivo<br>- Defaults inteligentes |
| **R7** | Consumo batería excesivo | Media | Bajo | - Optimizar polling GPS/BT<br>- Background modes eficientes<br>- Power monitoring |
| **R8** | Datos inexactos de FC | Media | Alto | - Validación cross-source<br>- Alertas outliers<br>- Calibración manual |

### 10.3 Plan de Mitigación Privacy (R1)

```
┌─────────────────────────────────────────────────────────────────┐
│              PRIVACY & SECURITY MEASURES                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DATA CLASSIFICATION:                                           │
│  ├── HIGH: Heart rate samples, GPS location                    │
│  ├── MEDIUM: Workout summaries, preferences                    │
│  └── LOW: App settings, UI state                               │
│                                                                 │
│  STORAGE:                                                       │
│  ├── Local: Encrypted Core Data (AES-256)                      │
│  ├── Keychain: Auth tokens, API keys                           │
│  └── Cloud: Aggregated data only, no raw HR                    │
│                                                                 │
│  PERMISSIONS:                                                   │
│  ├── HealthKit: Read HR, Write Workouts                        │
│  ├── Bluetooth: Garmin connection                              │
│  ├── Location: During workout only (WhenInUse)                 │
│  └── Background: Audio, Location updates                       │
│                                                                 │
│  COMPLIANCE:                                                    │
│  ├── GDPR: Data export, deletion on request                    │
│  ├── CCPA: Opt-out tracking                                    │
│  └── App Store Guidelines 5.1.1, 5.1.2                         │
│                                                                 │
│  USER CONTROLS:                                                 │
│  ├── Delete all data                                           │
│  ├── Export data (JSON/GPX)                                    │
│  ├── Revoke permissions                                        │
│  └── Anonymous mode (no cloud sync)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. Dependencias Técnicas

### 11.1 Frameworks Apple (Required)

| Framework | Uso | Versión Min |
|-----------|-----|-------------|
| **SwiftUI** | UI principal | iOS 16.0 |
| **HealthKit** | Datos FC, workouts | iOS 16.0 |
| **CoreBluetooth** | Conexión Garmin | iOS 16.0 |
| **AVFoundation** | Audio metrónomo | iOS 16.0 |
| **MediaPlayer** | Control música | iOS 16.0 |
| **CoreLocation** | GPS backup | iOS 16.0 |
| **BackgroundTasks** | Sesiones background | iOS 16.0 |
| **Swift Charts** | Visualizaciones | iOS 16.0 |
| **StoreKit 2** | Subscripciones | iOS 16.0 |

### 11.2 SDKs Terceros

| SDK | Propósito | Licencia | Riesgo |
|-----|-----------|----------|--------|
| **Garmin Connect IQ SDK** | Comunicación reloj | Garmin License | Medio - API changes |
| **Spotify iOS SDK** | Control playback | Spotify TOS | Bajo |
| **Firebase** | Analytics, Crash | Google TOS | Bajo |

### 11.3 Dependencias de Equipo

```
┌─────────────────────────────────────────────────────────────────┐
│                    TEAM DEPENDENCIES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DEVELOPMENT:                                                   │
│  ├── iOS Developer (SwiftUI, HealthKit)      2 FTE             │
│  ├── iOS Developer (Audio, Bluetooth)        1 FTE             │
│  └── QA Engineer                             0.5 FTE           │
│                                                                 │
│  DESIGN:                                                        │
│  ├── UI/UX Designer                          0.5 FTE           │
│  └── Motion Designer (animations)            0.25 FTE          │
│                                                                 │
│  EXTERNAL:                                                      │
│  ├── Garmin Developer Support                As needed         │
│  ├── Apple Developer Support                 As needed         │
│  └── Security Auditor                        Q2, Q4            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 11.4 Requisitos de Dispositivo

| Requisito | Mínimo | Recomendado |
|-----------|--------|-------------|
| iOS Version | 16.0 | 17.0+ |
| iPhone | iPhone 11 | iPhone 13+ |
| Garmin | Fenix 5+ | Fenix 7 |
| Storage | 100 MB | 200 MB |
| Bluetooth | 4.0 | 5.0+ |

---

## 12. Roadmap

### 12.1 Timeline de Desarrollo

```
┌─────────────────────────────────────────────────────────────────┐
│                        ROADMAP 2026                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Q1 2026 - MVP                                                  │
│  ════════════════════════════════════════                       │
│  ├── Jan: Core architecture, HealthKit integration             │
│  ├── Feb: Garmin Bluetooth, basic training UI                  │
│  └── Mar: Audio engine, MVP testing, TestFlight beta           │
│                                                                 │
│  Q2 2026 - Launch                                               │
│  ════════════════════════════════════════                       │
│  ├── Apr: App Store submission, launch v1.0                    │
│  ├── May: Post-launch fixes, analytics setup                   │
│  └── Jun: v1.1 - Spotify integration, share features           │
│                                                                 │
│  Q3 2026 - Growth                                               │
│  ════════════════════════════════════════                       │
│  ├── Jul: v1.2 - Advanced analytics, training plans            │
│  ├── Aug: Premium subscription launch                          │
│  └── Sep: v1.3 - Social features, challenges                   │
│                                                                 │
│  Q4 2026 - Expansion                                            │
│  ════════════════════════════════════════                       │
│  ├── Oct: Apple Watch companion app                            │
│  ├── Nov: Coach/trainer features                               │
│  └── Dec: v2.0 planning, platform expansion                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 12.2 Milestones MVP (Q1)

| Milestone | Deliverables | Target Date |
|-----------|--------------|-------------|
| M1: Foundation | Project setup, architecture, CI/CD | Jan 15 |
| M2: Data Layer | HealthKit, Garmin BT, Core Data | Feb 1 |
| M3: Training Core | Interval engine, timer, lap logic | Feb 15 |
| M4: Audio | Metronome, voice, music overlay | Mar 1 |
| M5: UI Complete | All screens, animations | Mar 15 |
| M6: Beta | TestFlight, 50 beta users | Mar 25 |

### 12.3 Feature Prioritization (MoSCoW)

| Must Have (MVP) | Should Have (v1.1) | Could Have (v1.2+) | Won't Have (v1.x) |
|-----------------|--------------------|--------------------|-------------------|
| Interval config | Spotify integration | Social sharing | Multi-sport |
| Garmin HR/Pace | Apple Music | Challenges | AI coaching |
| Real-time display | Export GPX/TCX | Training plans | Video tutorials |
| AutoLap | Best session match | Leaderboards | Nutrition |
| Basic metrónomo | Voice coaching | Apple Watch | Team features |
| Session history | Share cards | Widget | Android |

---

## 13. Apéndices

### Apéndice A: Glosario

| Término | Definición |
|---------|------------|
| **BPM** | Beats Per Minute - Frecuencia cardíaca |
| **HIIT** | High-Intensity Interval Training |
| **AutoLap** | Marcador automático de vuelta |
| **Time in Zone** | Porcentaje de tiempo en zona FC objetivo |
| **Pace** | Ritmo de carrera (min/km) |
| **TRIMP** | Training Impulse - Carga de entrenamiento |

### Apéndice B: Referencias

1. Garmin Connect IQ SDK Documentation
2. Apple HealthKit Programming Guide
3. AVFoundation Audio Session Programming Guide
4. Spotify iOS SDK Reference
5. Human Interface Guidelines - Workout Apps

### Apéndice C: Changelog PRD

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-01-27 | Versión inicial del PRD |

---

## Aprobaciones

| Rol | Nombre | Fecha | Firma |
|-----|--------|-------|-------|
| Product Manager | | | |
| Tech Lead | | | |
| Design Lead | | | |
| Engineering Manager | | | |

---

*Documento generado para IntervalPro iOS App*
*Confidencial - Solo uso interno*
