# 🚀 Retos de Práctica: Haskell + GPIO (`libgpiod`)

¡Felicidades por dominar la integración básica de GPIO, concurrencia y FFI en Haskell! Este documento contiene 5 retos progresivos diseñados para poner a prueba y afianzar tus conocimientos en programación concurrente, gestión de tiempo y manejo de hardware.

---

## 📌 Requisitos Previos

* **Hardware asumido**: 
  * LED en Pin **256** (`DirOutput`).
  * Botón en Pin **271** (`DirInput`, `BiasPullDown`, `EdgeRising` / `EdgeBoth`).
* **Librerías sugeridas**: `Fuyu.GPIO`, `Control.Concurrent`, `Control.Monad`, `Data.Time.Clock`, `Control.Exception`.

---

## 🥊 Reto 1: Pulsación Corta vs. Pulsación Larga

### 🎯 Objetivo
Diferenciar la duración de la pulsación del botón leyendo el tiempo transcurrido entre que entran los 3.3V (`EventRisingEdge`) y caen a 0V (`EventFallingEdge`).

### 📋 Comportamiento Esperado
* **Pulsación Corta ($< 1$ segundo)**: Conmuta el estado del LED (Encendido / Apagado).
* **Pulsación Larga ($> 1$ segundo)**: El LED parpadea rápidamente 3 veces para indicar una acción especial.

### 💡 Pistas de Implementación
1. Configura el botón con `EdgeBoth`.
2. Al recibir `EventRisingEdge`, registra el tiempo inicial usando `getCurrentTime` (`Data.Time.Clock`).
3. Al recibir `EventFallingEdge`, vuelve a llamar a `getCurrentTime` y calcula la diferencia con `diffUTCTime`:
   ```haskell
   let duracion = diffUTCTime tFinal tInicial
   if duracion < 1.0
     then -- Pulsación corta: Conmutar LED
     else -- Pulsación larga: Parpadear 3 veces
   ```

---

## 🥊 Reto 2: Selector de Velocidad de Parpadeo (Control Concurrente)

### 🎯 Objetivo
Coordinar dos hilos independientes comunicados mediante un `MVar Int` que determina el tiempo de parpadeo del LED.

### 📋 Comportamiento Esperado
* **Hilo A (`ledWorker`)**: El LED parpadea en un bucle continuo. El tiempo de espera entre encendido y apagado depende del microsegundo actual almacenado en el `MVar`.
* **Hilo B (`buttonWorker`)**: Cada vez que se presiona el botón (3.3V), cambia la velocidad rotando en la siguiente lista de retardos:
  `1000000 µs (1s) -> 500000 µs (0.5s) -> 200000 µs (0.2s) -> 100000 µs (0.1s) -> 1000000 µs`

### 💡 Pistas de Implementación
* El hilo del LED lee la velocidad con `readMVar speedMVar` en cada iteración de su bucle sin bloquear al botón.
* El hilo del botón actualiza la velocidad con `modifyMVar_ speedMVar (\old -> return (siguienteVelocidad old))`.

---

## 🥊 Reto 3: Modo "Código Secreto / Caja Fuerte" (Patrón de Pulsaciones)

### 🎯 Objetivo
Detectar una secuencia o patrón específico de pulsaciones rápidas antes de activar una salida.

### 📋 Comportamiento Esperado
* El LED solo se enciende si el usuario presiona el botón **3 veces seguidas en un lapso total menor a 2 segundos**.
* Si pasan más de 2 segundos sin presionar, la cuenta de pulsaciones se reinicia a `0`.
* Una vez desbloqueado (LED encendido), otra pulsación vuelve a bloquear la "caja fuerte" (apaga el LED).

### 💡 Pistas de Implementación
* Guarda una tupla de estado en un `MVar`: `(Int, UTCTime)` conteniendo `(contadorPulsaciones, tiempoUltimaPulsacion)`.
* Al recibir un evento de botón, comprueba cuánto tiempo ha pasado desde la última pulsación. Si es mayor a 2.0 segundos, reinicia el contador a `1`; si es menor, suma `1` al contador.

---

## 🥊 Reto 4: Reporte Estadístico de Sesión al Salir (Ctrl+C)

### 🎯 Objetivo
Recolectar métricas de uso del sistema durante la ejecución e imprimirlas en un informe limpio al presionar `Ctrl+C`.

### 📋 Comportamiento Esperado
* Durante la ejecución, registra el momento en que inicia la aplicación y cada clic realizado.
* Al presionar `Ctrl+C`, en lugar de solo decir *"Finalizado"*, se imprime un reporte estadístico en la consola:

```text
========================================
       📊 REPORTE FINAL DE SESIÓN
========================================
• Tiempo total activo: 45.2 segundos
• Total de clics registrados: 12
• Frecuencia promedio: 20.0 clics/minuto
========================================
¡Programa finalizado limpiamente!
```

### 💡 Pistas de Implementación
* Crea un `MVar SessionStats` con `(UTCTime, Int)` representando `(horaInicio, totalClics)`.
* En la función `handleMainExit` de tu `catch`, lee el estado final del `MVar`, calcula el tiempo transcurrido con `getCurrentTime` y formatea la salida con `printf` o `putStrLn`.

---

## 🥊 Reto 5: Dimmer / Atenuador de Luz por PWM en Software

### 🎯 Objetivo
Controlar la intensidad del brillo del LED modulando el ancho de pulso (*Software PWM*).

### 📋 Comportamiento Esperado
* El LED tiene 4 niveles de brillo: `0% (Apagado) -> 25% -> 50% -> 100% -> 0%`.
* Cada pulsación del botón incrementa el nivel de brillo.
* El hilo del LED genera un ciclo PWM de período corto (ej. 10ms = 10000 µs):
  * **25%**: LED Encendido `2500 µs`, Apagado `7500 µs`.
  * **50%**: LED Encendido `5000 µs`, Apagado `5000 µs`.
  * **100%**: LED Encendido `10000 µs`, Apagado `0 µs`.

### 💡 Pistas de Implementación
* Guarda el ciclo de trabajo (*Duty Cycle*) como un flotante `Double` entre `0.0` y `1.0` en un `MVar`.
* En el hilo del LED:
  ```haskell
  let periodoTotal = 10000 -- 10 ms
  let tiempoON = round (periodoTotal * dutyCycle)
  let tiempoOFF = periodoTotal - tiempoON
  setValue request pinLED LineActive
  threadDelay tiempoON
  setValue request pinLED LineInactive
  threadDelay tiempoOFF
  ```

---

¡Disfruta resolviendo estos retos mañana! 🚀
