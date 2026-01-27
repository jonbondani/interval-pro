# IntervalPro

**Entrenamiento por intervalos HIIT basado en frecuencia cardíaca para iOS**

IntervalPro es una aplicación iOS diseñada para corredores que buscan optimizar su entrenamiento mediante intervalos HIIT con zonas de frecuencia cardíaca precisas. Integración nativa con Garmin Fenix y metrónomo audible sobre tu música favorita.

---

## Características

### Entrenamiento Inteligente
- **Zonas de FC configurables**: Work 160/170/180 BPM, Rest 150 BPM
- **Intervalos personalizables**: Duración de trabajo/descanso, series (2-20)
- **Warm-up y Cool-down** opcionales
- **Plantillas predefinidas**: Principiante, Intermedio, Avanzado

### Integración Garmin Fenix
- **Conexión Bluetooth LE** directa con HR Service (0x180D)
- **Datos en tiempo real**: Frecuencia cardíaca, velocidad, ritmo, cadencia
- **AutoLap automático** al cambiar de fase
- **Reconexión automática** con backoff exponencial (3 intentos)
- **Fallback a HealthKit** cuando Garmin no está disponible

### Audio Overlay
- **Metrónomo audible** (150-190 BPM) sobre Spotify/Apple Music
- **Anuncios de voz**: Cambios de fase, advertencias de tiempo
- **Alertas de zona**: "Sube intensidad", "Baja intensidad"
- **Ducking inteligente**: Baja música durante anuncios

### Análisis y Progresión
- **Best Session Match**: Compara con tu mejor sesión similar
- **Tiempo en zona**: Porcentaje de tiempo en zona objetivo
- **Histórico de sesiones**: Tendencias semanales, récords personales
- **Scoring**: Puntuación 0-100 basada en rendimiento
- **Export**: Strava, GPX/TCX, Share cards

---

## Requisitos

| Requisito | Mínimo | Recomendado |
|-----------|--------|-------------|
| iOS | 16.0 | 17.0+ |
| iPhone | iPhone 11 | iPhone 13+ |
| Garmin | Fenix 5+ | Fenix 7 |
| Xcode | 15.0 | 15.2+ |
| Swift | 5.9 | 5.9+ |

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/yourusername/intervalpro-ios.git
cd intervalpro-ios
```

### 2. Abrir en Xcode

```bash
open IntervalPro.xcodeproj
```

### 3. Configurar signing

1. Selecciona el target `IntervalPro`
2. En **Signing & Capabilities**, selecciona tu Team
3. Cambia el Bundle Identifier si es necesario

### 4. Configurar capabilities

Asegúrate de tener habilitados:
- HealthKit
- Background Modes (Audio, Bluetooth, Location)

### 5. Build and Run

```bash
# Desde terminal
xcodebuild -scheme IntervalPro -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# O usa Cmd+R en Xcode
```

---

## Arquitectura

### Estructura del Proyecto

```
IntervalPro/
├── App/
│   ├── IntervalProApp.swift      # Entry point
│   ├── AppState.swift            # Global state
│   ├── ContentView.swift         # Root navigation
│   └── NavigationRouter.swift    # Centralized routing
│
├── Features/
│   ├── Training/
│   │   ├── Views/                # SwiftUI views
│   │   ├── ViewModels/           # @MainActor ViewModels
│   │   └── Models/               # Domain models
│   ├── Plans/
│   ├── Progress/
│   └── Settings/
│
├── Core/
│   ├── Bluetooth/
│   │   ├── GarminManager.swift   # BLE connection
│   │   └── GarminManaging.swift  # Protocol
│   ├── Health/
│   │   ├── HealthKitManager.swift
│   │   └── HRDataService.swift   # Unified HR stream
│   ├── Audio/
│   │   └── MetronomeEngine.swift
│   └── Persistence/
│       ├── CoreDataStack.swift   # Encrypted storage
│       └── Repositories/
│
├── Shared/
│   ├── Components/               # Reusable UI
│   ├── Extensions/
│   └── Utilities/
│       └── Logger.swift          # os.Logger wrapper
│
└── Tests/
    ├── UnitTests/
    └── UITests/
```

### Patrones de Diseño

| Patrón | Uso |
|--------|-----|
| **MVVM** | ViewModels con `@MainActor` y `@Published` |
| **Dependency Injection** | Protocolos para todos los managers |
| **Repository Pattern** | Abstracción de Core Data |
| **Combine** | Streams reactivos para HR, connection state |

### Flujo de Datos HR

```
┌─────────────┐     ┌─────────────┐
│   Garmin    │     │  HealthKit  │
│   Manager   │     │   Manager   │
└──────┬──────┘     └──────┬──────┘
       │                   │
       ▼                   ▼
┌─────────────────────────────────┐
│         HRDataService           │
│  • Source prioritization        │
│  • Outlier filtering            │
│  • Zone tracking                │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│      TrainingViewModel          │
│  • UI state                     │
│  • Timer logic                  │
└─────────────────────────────────┘
```

---

## Configuración

### Zonas de Frecuencia Cardíaca

Las zonas son **siempre configurables**, nunca hardcodeadas:

```swift
// Correcto
let zone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
if zone.contains(currentHR) { ... }

// Incorrecto - NUNCA hacer esto
if currentHR > 170 { ... }  // ❌ Hardcoded
```

### Variables de Entorno

Crea un archivo `Secrets.swift` (no commitear):

```swift
enum Secrets {
    static let spotifyClientId = "your-client-id"
    static let spotifyRedirectUri = "intervalpro://callback"
}
```

---

## Testing

### Ejecutar Tests

```bash
# Todos los tests
xcodebuild test \
  -scheme IntervalPro \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Tests específicos
xcodebuild test \
  -scheme IntervalPro \
  -only-testing:IntervalProTests/HeartRateZoneTests
```

### Coverage

```bash
# Generar reporte
xcodebuild test \
  -scheme IntervalPro \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# Ver reporte
xcrun xccov view --report TestResults.xcresult
```

### Tests Incluidos

| Suite | Tests | Coverage Target |
|-------|-------|-----------------|
| HeartRateZoneTests | 14 | 100% |
| TrainingPlanTests | 12 | 100% |
| SessionRepositoryTests | 12 | 90% |
| GarminManagerTests | 12 | 85% |
| HealthKitManagerTests | 11 | 85% |
| HRDataServiceTests | 10 | 85% |

---

## Guía de Desarrollo

### Reglas del Proyecto

Ver `CLAUDE.md` para reglas detalladas. Resumen:

| Regla | Descripción |
|-------|-------------|
| **SwiftUI only** | No UIKit en código nuevo |
| **No hardcode BPM** | Usar `HeartRateZone` siempre |
| **TDD** | Tests primero, 80% coverage |
| **Privacy** | HR data encriptada, logs redactados |
| **async/await** | No completion handlers |
| **@MainActor** | En todos los ViewModels |
| **os.Logger** | No `print()` |

### SwiftLint

El proyecto usa SwiftLint con reglas customizadas:

```bash
# Ejecutar lint
swiftlint

# Autocorrect
swiftlint --fix
```

### Commits

Formato de commits:

```
feat: Add metronome BPM configuration
fix: Resolve Garmin reconnection loop
docs: Update README with architecture
test: Add HRDataService zone tracking tests

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Roadmap

### v1.0 - MVP (Q1 2026)
- [x] Estructura del proyecto
- [x] Core Data con encriptación
- [x] HealthKit integration
- [x] Garmin BLE connection
- [x] HR Data Service unificado
- [ ] Interval Timer engine
- [ ] Metronome audio
- [ ] Training UI
- [ ] Session summary
- [ ] App Store submission

### v1.1 - Enhanced (Q2 2026)
- [ ] Spotify integration
- [ ] Apple Music integration
- [ ] Export to Strava
- [ ] Share cards
- [ ] Voice coaching avanzado

### v1.2 - Social (Q3 2026)
- [ ] Challenges
- [ ] Leaderboards
- [ ] Training plans compartidos

### v2.0 - Platform (Q4 2026)
- [ ] Apple Watch companion app
- [ ] Coach/trainer features
- [ ] AI-powered recommendations

---

## Contribuir

1. Fork el repositorio
2. Crea una rama: `git checkout -b feature/amazing-feature`
3. Haz commits: `git commit -m 'feat: Add amazing feature'`
4. Push: `git push origin feature/amazing-feature`
5. Abre un Pull Request

### Antes de PR

- [ ] Tests pasan: `xcodebuild test`
- [ ] SwiftLint limpio: `swiftlint`
- [ ] Coverage > 80% en código nuevo
- [ ] Previews funcionan para nuevas views

---

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [PRD_IntervalPro.md](./PRD_IntervalPro.md) | Product Requirements Document completo |
| [CLAUDE.md](./CLAUDE.md) | Reglas de desarrollo y contexto |
| [PLAN.md](./PLAN.md) | Plan de desarrollo con tareas |

---

## Licencia

Este proyecto es privado. Todos los derechos reservados.

---

## Contacto

**Desarrollador**: Daniel López
**Ubicación**: Marbella, España

---

<p align="center">
  <b>IntervalPro</b> - Entrena inteligente, mejora constante
</p>
