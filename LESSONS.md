# LESSONS.md - Lecciones Aprendidas

## IntervalPro iOS Development

**Fecha de inicio:** Enero 2026
**Última actualización:** 6 Febrero 2026
**Estado:** En desarrollo activo

---

## Tabla de Contenidos

1. [Arquitectura y Diseño](#1-arquitectura-y-diseño)
2. [Integración Bluetooth (Garmin)](#2-integración-bluetooth-garmin)
3. [Audio y Música](#3-audio-y-música)
4. [HealthKit y Datos de Salud](#4-healthkit-y-datos-de-salud)
5. [SwiftUI y UI](#5-swiftui-y-ui)
6. [CoreData y Persistencia](#6-coredata-y-persistencia)
7. [Testing](#7-testing)
8. [Errores Comunes y Soluciones](#8-errores-comunes-y-soluciones)
9. [Optimizaciones](#9-optimizaciones)
10. [Decisiones de Diseño](#10-decisiones-de-diseño)

---

## 1. Arquitectura y Diseño

### MVVM con Dependency Injection

**Lo que funcionó bien:**
```swift
@MainActor
final class TrainingViewModel: ObservableObject {
    // Dependencias inyectadas via protocolo
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging
    private let audioEngine: AudioEngineProtocol

    init(
        garminManager: GarminManaging = GarminManager.shared,
        healthKitManager: HealthKitManaging = HealthKitManager.shared,
        audioEngine: AudioEngineProtocol = MetronomeEngine()
    ) {
        // Permite testing con mocks
    }
}
```

**Lección:** Usar protocolos para todas las dependencias externas permite:
- Testing con mocks sin dependencias reales
- Cambiar implementaciones sin modificar ViewModels
- Código más desacoplado y mantenible

### Async/Await vs Combine

**Decisión:** Usar async/await para operaciones puntuales, Combine para streams continuos.

```swift
// Operaciones puntuales: async/await
func saveSession() async throws {
    try await repository.save(session)
}

// Streams continuos: Combine
garminManager.heartRatePublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] hr in
        self?.heartRate = hr
    }
    .store(in: &cancellables)
```

**Lección:** No mezclar paradigmas innecesariamente. Combine es mejor para datos que fluyen continuamente (HR, cadencia), async/await para acciones discretas.

---

## 2. Integración Bluetooth (Garmin)

### Descubrimiento de Dispositivos BLE

**Problema encontrado:** Los dispositivos Garmin no siempre aparecen en el primer scan.

**Solución implementada:**
```swift
// Deep scan mode con múltiples intentos
func startDeepScan() {
    centralManager.scanForPeripherals(
        withServices: [hrServiceUUID, rscServiceUUID],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )

    // Timeout y retry
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        if self.connectionState == .scanning {
            self.stopScan()
            self.startDeepScan() // Reintentar
        }
    }
}
```

**Lección:** BLE requiere paciencia. Implementar:
- Múltiples intentos de scan
- Timeouts configurables
- Persistencia del device ID para reconexión rápida

### Reconexión Automática

**Problema:** El Garmin se desconecta durante entrenamientos (sudor, distancia, interferencias).

**Solución:**
```swift
func handleDisconnect() async {
    for attempt in 1...maxReconnectAttempts {
        connectionState = .reconnecting(attempt: attempt)

        // Backoff exponencial
        try? await Task.sleep(for: .seconds(reconnectDelay * Double(attempt)))

        if await attemptReconnect() {
            connectionState = .connected
            return
        }
    }

    // Fallback a HealthKit
    connectionState = .failed(.maxReconnectAttemptsExceeded)
    await activateHealthKitFallback()
}
```

**Lección:** SIEMPRE tener un fallback. El usuario no debe perder su entreno por problemas de conexión.

### Servicios BLE Estándar

**Descubrimiento:** Los Garmin Fenix exponen servicios BLE estándar:
- Heart Rate Service: `0x180D`
- Running Speed & Cadence: `0x1814`

**Lección:** No es necesario el Garmin Connect IQ SDK para datos básicos. Los servicios BLE estándar funcionan perfectamente y son más simples de implementar.

---

## 3. Audio y Música

### AVAudioSession Configuration

**Configuración crítica para overlay:**
```swift
try audioSession.setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers, .duckOthers]
)
```

**Lección:**
- `.mixWithOthers` permite que el metrónomo suene sobre Spotify/Apple Music
- `.duckOthers` baja el volumen de la música durante anuncios de voz
- Activar la sesión ANTES de reproducir audio

### Limitaciones de iOS con Spotify

**Descubrimiento importante:** iOS no permite que una app controle la reproducción de otra.

**Lo que funciona:**
```swift
// Leer estado via MPNowPlayingInfoCenter
let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo
let title = nowPlaying?[MPMediaItemPropertyTitle] as? String
let isPlaying = MPNowPlayingInfoCenter.default().playbackState == .playing
```

**Lo que NO funciona:**
```swift
// Esto NO existe - los URL schemes de control de Spotify no funcionan
UIApplication.shared.open(URL(string: "spotify:pause")!) // FALSO
```

**Lección:** Documentar limitaciones de plataforma claramente. Ofrecer Apple Music como alternativa con control completo.

### Metrónomo de Alta Precisión

**Problema:** Timer básico no es suficientemente preciso para un metrónomo musical.

**Solución:** Usar CADisplayLink o dispatch source timer:
```swift
let timer = DispatchSource.makeTimerSource(queue: audioQueue)
timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
timer.setEventHandler { [weak self] in
    self?.playClick()
}
```

**Lección:** Para audio que requiere precisión de milisegundos, no usar Timer. Usar DispatchSourceTimer o CADisplayLink.

---

## 4. HealthKit y Datos de Salud

### Autorización Incremental

**Lección:** Solicitar permisos de HealthKit SOLO cuando se necesitan, no en el onboarding.

```swift
// Malo: Pedir todo al inicio
func requestAllPermissions() async {
    // Usuario se asusta con tantos permisos
}

// Bueno: Pedir cuando se va a usar
func startWorkout() async {
    if !hasWorkoutPermission {
        await requestWorkoutPermission()
    }
    // Continuar con el workout
}
```

### Datos de Salud son Sensibles

**Requisitos de privacidad implementados:**
- CoreData con encriptación AES-256
- No logging de valores HR en producción
- Opción de borrar todos los datos
- No sync de datos raw a cloud

```swift
func logHRSample(_ sample: HRSample) {
    #if DEBUG
    print("HR: \(sample.bpm)")
    #endif
    // Producción: solo agregar a estadísticas
}
```

**Lección:** Los datos de frecuencia cardíaca son datos de salud protegidos. Tratarlos con el máximo cuidado.

---

## 5. SwiftUI y UI

### SwiftLint type_body_length

**Problema:** SwiftLint tiene un límite de 500 líneas por tipo.

**Solución:** Extraer componentes a archivos separados.

```swift
// Antes: TrainingView.swift con 800+ líneas
// Después:
// - TrainingView.swift (~300 líneas)
// - TrainingViewComponents.swift (MusicWidget, MetricCard, etc.)
// - WalkingWorkoutViews.swift (componentes de caminata)
```

**Lección:** Componentes pequeños y enfocados. Si un archivo crece mucho, extraer.

### Añadir Archivos a Xcode Project

**Problema:** Crear archivos Swift manualmente no los añade a project.pbxproj.

**Solución:** Script Python o usar Xcode directamente.

**Lección:** Cuando se trabaja fuera de Xcode, asegurarse de que los archivos estén en el proyecto. Error típico: "Cannot find 'ComponentName' in scope"

### GeometryReader para Layouts Adaptativos

**Patrón usado:**
```swift
GeometryReader { geo in
    if geo.size.width > 400 {
        HStack { /* Layout ancho */ }
    } else {
        VStack { /* Layout estrecho */ }
    }
}
```

**Lección:** Usar GeometryReader para layouts que dependen del tamaño, no de sizeClass únicamente.

### Dynamic Type y Accesibilidad

**Siempre usar fuentes semánticas:**
```swift
// Malo
.font(.system(size: 24))

// Bueno
.font(.title2)
.font(.system(.title2, design: .rounded, weight: .bold))
```

**Lección:** Las fuentes semánticas escalan con Dynamic Type. Probar con accessibility sizes.

---

## 6. CoreData y Persistencia

### NSPredicate y Filtros

**Bug encontrado:** Sessions guardadas no aparecían en la lista.

**Causa:**
```swift
// Esto filtraba las sesiones detenidas (isCompleted = false)
request.predicate = NSPredicate(format: "isCompleted == YES")
```

**Fix:**
```swift
// Mostrar todas las sesiones
// Sin predicate, solo ordenar por fecha
request.sortDescriptors = [
    NSSortDescriptor(keyPath: \TrainingSessionEntity.startDate, ascending: false)
]
```

**Lección:** Revisar los predicates de fetch cuando los datos "desaparecen". El filtro puede ser demasiado restrictivo.

### Encoding de Datos Complejos

**Patrón para arrays en CoreData:**
```swift
// Guardar
self.intervalsData = try JSONEncoder().encode(session.intervals)

// Leer
if let data = intervalsData {
    intervals = try JSONDecoder().decode([IntervalRecord].self, from: data)
}
```

**Lección:** Para arrays de structs, usar JSON encoding en un atributo Binary Data.

---

## 7. Testing

### Mocks para Dependencias de Hardware

```swift
class MockGarminManager: GarminManaging {
    var connectionState: GarminConnectionState = .connected
    var heartRatePublisher: AnyPublisher<Int, Never> {
        Just(165).eraseToAnyPublisher()
    }

    func connect() async throws {
        connectionState = .connected
    }
}
```

**Lección:** Crear mocks que permitan simular diferentes estados (conectado, desconectado, error).

### Tests Async con XCTest

```swift
func test_startWorkout_updatesState() async {
    let sut = TrainingViewModel(garminManager: MockGarminManager())

    await sut.startWorkout()

    XCTAssertEqual(sut.currentPhase, .warmup)
}
```

**Lección:** Usar `async` en tests cuando se prueban métodos async. Usar expectation para Combine publishers.

---

## 8. Errores Comunes y Soluciones

### Error: "Cannot find 'X' in scope"

**Causas posibles:**
1. Archivo no añadido al target en Xcode
2. Typo en el nombre del tipo
3. Archivo en carpeta incorrecta

**Solución:** Verificar en project.pbxproj que el archivo está incluido.

### Error: Thread Safety con @Published

**Problema:**
```swift
// Crash: Publishing changes from background threads
backgroundQueue.async {
    self.heartRate = newValue // CRASH
}
```

**Solución:**
```swift
DispatchQueue.main.async {
    self.heartRate = newValue
}
// O mejor:
await MainActor.run {
    self.heartRate = newValue
}
```

### Error: Retain Cycles en Closures

**Problema:**
```swift
publisher.sink { value in
    self.process(value) // Strong reference cycle
}
```

**Solución:**
```swift
publisher.sink { [weak self] value in
    self?.process(value)
}
```

---

## 9. Optimizaciones

### Throttling de Updates de UI

**Problema:** Updates de HR cada segundo causan re-renders excesivos.

**Solución:**
```swift
// Solo actualizar si cambia significativamente
if abs(newHR - currentHR) >= 2 {
    currentHR = newHR
}
```

### Filtrado de Outliers

**Implementación:**
```swift
private var hrBuffer: [Int] = []
private let bufferSize = 5

func filterHR(_ value: Int) -> Int {
    hrBuffer.append(value)
    if hrBuffer.count > bufferSize {
        hrBuffer.removeFirst()
    }
    return hrBuffer.sorted()[hrBuffer.count / 2] // Mediana
}
```

**Lección:** Los sensores de HR pueden dar valores erráticos. Usar filtro de mediana.

---

## 10. Decisiones de Diseño

### Zonas Basadas en Cadencia, no HR Real

**Decisión:** El tracking de zonas usa cadencia (SPM) como proxy de intensidad, no frecuencia cardíaca real.

**Razón:**
- La cadencia es más controlable que el HR
- El metrónomo guía la cadencia directamente
- El HR responde con delay a cambios de intensidad
- Más actionable para el usuario

### Español como Idioma Principal

**Decisión:** UI y voz en español por defecto.

**Razón:**
- Usuario objetivo está en España
- Mejor experiencia durante entrenamientos
- Inglés disponible como alternativa

### Spotify Preferido sobre Apple Music

**Decisión:** Detectar Spotify primero cuando está instalado.

**Razón:**
- Mayor base de usuarios
- Mejor detección de estado de reproducción
- Apple Music como fallback con control completo

---

## Conclusiones Generales

1. **Siempre tener fallbacks** - Hardware falla, conexiones se pierden
2. **Probar en dispositivo real** - El simulador no replica BLE, sensores, etc.
3. **Documentar limitaciones de plataforma** - iOS tiene restricciones no obvias
4. **Mantener archivos pequeños** - Facilita mantenimiento y testing
5. **Usar protocolos** - Permite mocks y flexibilidad
6. **Tratar datos de salud con cuidado** - Son sensibles y regulados
7. **No hardcodear valores** - Todo configurable por el usuario

---

*Documento actualizado continuamente durante el desarrollo.*
