{-# LANGUAGE OverloadedStrings #-}

module Main where
import Data.Time (UTCTime(..), getCurrentTime, defaultTimeLocale, formatTime)
import Control.Exception (catch, IOException)
import Numeric (showFFloat)
import Control.Monad (forever)
import Control.Concurrent
 (threadDelay, forkIO,
  MVar, newMVar, modifyMVar_, readMVar,
 )
import Fuyu.GPIO 


{-
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
-}

-------------------------------------------------
-- GLOBAL 
-------------------------------------------------
chipPath :: FilePath
chipPath = "/dev/gpiochip0"

bufferCapacity :: EventBufferCapacity
bufferCapacity = EventBufferCapacity 1

printState :: State -> IO()
printState state = do
  putStr $ unlines ["",
                    line,
                    "       📊 REPORTE FINAL DE SESIÓN",
                    line,
                    "• Tiempo total activo: " ++ seconds ++ " segundos", 
                    "• Total de clics registrados: " ++ show clicks, 
                    "• Frecuencia promedio: " ++ showFFloat (Just 4) promFrecuency "" ++ " clics/minuto",
                    line   
                   ] 
  
  where line = "========================================" :: String 
        seconds =
          let format = "%S.%4q"
              fechaFormateada = formatTime defaultTimeLocale format (fst state)
          in  fechaFormateada
        clicks = snd state
        promFrecuency = 
          let res = (fromIntegral clicks / read seconds ) * 60 :: Float         
          in res 
        
       
type State = (UTCTime, Int)

-------------------------------------------------
-- LED 
-------------------------------------------------

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

btnWorker :: LineRequest -> EventBuffer -> MVar State -> IO()
btnWorker request buffer buzonState = do
  res <- waitEdgeEvents request oneSecondNs
  case res of
     EventsReady _ -> do
       modifyMVar_ buzonState $ \(hora, clicks) -> return (hora, clicks + 1)
              
       threadDelay 200000                 -- 🛡️ Antirrebote de 200 ms
       flushInitialEvents request buffer  -- 🧹 Descartar ráfagas residuales

     Timeout -> return ()
  where 
    oneSecondNs :: TimeoutNs 
    oneSecondNs = Nanoseconds 1000000000 -- 1 segundo

  

-- | Limpia y descarta eventos iniciales o residuales (antirrebote).
flushInitialEvents :: LineRequest -> EventBuffer -> IO ()
flushInitialEvents request buffer = do
  res <- waitEdgeEvents request (Nanoseconds 0)
  case res of
    EventsReady readyReq -> do
      _ <- readEdgeEvents readyReq buffer
      flushInitialEvents request buffer
    Timeout -> return ()

-------------------------------------------------
-- APP 
-------------------------------------------------
  
main :: IO()
main = do
  putStrLn "INICIANDO"
  initialTime <- getCurrentTime  
  initialState <- newMVar (initialTime, 0)


  runApp initialState `catch` (`handleExit` initialState)
  where
    handleExit :: IOException -> MVar State ->IO ()
    handleExit _ buzonState = do state <- readMVar buzonState 
                                 printState state 
                                 putStrLn "\n¡Programa finalizado limpiamente!"
  

runApp :: MVar State -> IO()
runApp buzon = do
  withChip chipPath $ \chip -> do  
    withLineSettings $ \btnStgs -> do
      btnSettings btnStgs
      withLineConfig $ \config -> do
        addConfigToLineSettings config [btnOffset] btnStgs
        withLineRequest chip Nothing config $ \request -> do
          withEdgeEventBuffer bufferCapacity $ \buffer -> do
            flushInitialEvents request buffer
            forever $ btnWorker request buffer buzon  
