module Main where
import Fuyu.GPIO
import Control.Concurrent (threadDelay, forkIO, MVar, newMVar, modifyMVar_, readMVar)
import Control.Exception (catch, IOException)
import Control.Monad (forever)

{-
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
-}

-------------------------------------------------
-- GLOBAL 
-------------------------------------------------
chipPath :: FilePath
chipPath = "/dev/gpiochip0"

initialLooptimeMs :: LooptimeState
initialLooptimeMs = OneSec

type Microseconds = Int

data LooptimeState = OneSec | HalfSec | FifthOfSec | TenthOfSec

oneSecMs :: Microseconds
oneSecMs = 1000000

halfSecMs :: Microseconds
halfSecMs = 500000

fifthOfSec :: Microseconds
fifthOfSec = 200000

tenthOfSec :: Microseconds
tenthOfSec = 100000

bufferCapacity :: EventBufferCapacity
bufferCapacity = EventBufferCapacity 1

-------------------------------------------------
-- LED 
-------------------------------------------------
ledOffset :: LineOffset
ledOffset = LineOffset 256 

ledSettings :: LineSettings -> IO()
ledSettings settings = do
  setDirection settings DirOutput

ledWorker :: LineRequest -> MVar LooptimeState -> IO()
ledWorker req buzon = do
  lts <- readMVar buzon
  case lts of
    OneSec     -> loop oneSecMs
    HalfSec    -> loop halfSecMs
    FifthOfSec -> loop fifthOfSec
    TenthOfSec -> loop tenthOfSec
    
  where loop time = do setValue req ledOffset LineActive
                       threadDelay time 
                       setValue req ledOffset LineInactive
                       threadDelay time 
                      

siguienteVelocidad :: LooptimeState -> LooptimeState 
siguienteVelocidad OneSec     = HalfSec
siguienteVelocidad HalfSec    = FifthOfSec
siguienteVelocidad FifthOfSec = TenthOfSec
siguienteVelocidad TenthOfSec = OneSec


-------------------------------------------------
-- BUTTON  
-------------------------------------------------
btnOffset :: LineOffset
btnOffset = LineOffset 271

btnSettings :: LineSettings -> IO()
btnSettings settings = do
  setDirection settings DirInput
  setBias settings BiasPullDown
  setEdgeDetection settings EdgeRising 

-- | Limpia y descarta eventos iniciales o residuales (antirrebote).
flushInitialEvents :: LineRequest -> EventBuffer -> IO ()
flushInitialEvents request buffer = do
  res <- waitEdgeEvents request (Nanoseconds 0)
  case res of
    EventsReady readyReq -> do
      _ <- readEdgeEvents readyReq buffer
      flushInitialEvents request buffer
    Timeout -> return ()

buttonWorker :: LineRequest -> EventBuffer -> MVar LooptimeState -> IO ()
buttonWorker req buffer buzon = do
  res <- waitEdgeEvents req fiveSecondsNs
  case res of
    EventsReady readyReq -> do
      _ <- readEdgeEvents readyReq buffer
      modifyMVar_ buzon (return . siguienteVelocidad)
      threadDelay 200000            -- 🛡️ Antirrebote de 200 ms
      flushInitialEvents req buffer  -- 🧹 Descartar ráfagas residuales
    Timeout -> return ()

  where 
    fiveSecondsNs :: TimeoutNs 
    fiveSecondsNs = Nanoseconds 5000000000 -- 5 segundos

-------------------------------------------------
-- APP 
-------------------------------------------------
  
main :: IO()
main = do
  runApp `catch` handleExit
  where
    handleExit :: IOException -> IO ()
    handleExit err = putStrLn ("\n¡Programa finalizado limpiamente!" ++ show err)
  

runApp :: IO()
runApp = do
  putStrLn "INICIANDO"
  initialBuzon <- newMVar initialLooptimeMs
  withChip chipPath $ \chip -> do  
    putStrLn "CONFIGURANDO SETTINGS PARA EL BOTON"
    withLineSettings $ \btnStgs -> do
      btnSettings btnStgs
      
      putStrLn "CONFIGURANDO SETTINGS PARA EL LED"    
      withLineSettings $ \ledStgs -> do 
        ledSettings ledStgs
          
        withLineConfig $ \config -> do
          putStrLn "CREANDO UN CONFIG GLOBAL"
          addConfigToLineSettings config [ledOffset] ledStgs
          addConfigToLineSettings config [btnOffset] btnStgs
                  
          withLineRequest chip Nothing config $ \request -> do
            withEdgeEventBuffer bufferCapacity $ \buffer -> do
              putStrLn "CREANDO UN REQUEST GLOBAL Y BUFFER"
              flushInitialEvents request buffer
              setValue request ledOffset LineInactive
              _ <- forkIO $ forever $ ledWorker request initialBuzon
              forever $ buttonWorker request buffer initialBuzon  
