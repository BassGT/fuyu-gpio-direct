module Main where
import Control.Exception (catch, IOException)
import Control.Monad (forever)
import Control.Concurrent (threadDelay, MVar, newMVar, modifyMVar_, readMVar, forkIO)
import Data.Time (UTCTime(..), getCurrentTime, diffUTCTime)
import Fuyu.GPIO 

{-
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
-}

-------------------------------------------------
-- GLOBAL 
-------------------------------------------------
chipPath :: FilePath
chipPath = "/dev/gpiochip0"

bufferCapacity :: EventBufferCapacity
bufferCapacity = EventBufferCapacity 1

data State = State {
  clickCounts :: ClickCounts, 
  clickTime   :: Maybe UTCTime
} deriving (Show, Eq)

data ClickCounts = ZeroClicks | OneClick | TwoClicks | ThreeClicks deriving (Eq, Show) 

isDiffLessThan2Secs :: UTCTime -> UTCTime -> Bool
isDiffLessThan2Secs utc1 utc2 = max utc1 utc2 `diffUTCTime` min utc1 utc2 <= 2  

initialState :: State
initialState = State ZeroClicks Nothing

{-
updateState :: UTCTime -> State -> State
updateState newTime state = case (clickCounts state, clickTime state) of
      (ZeroClicks, _) -> 
        State OneClick (Just newTime)
    
      (OneClick, Just lastT)
        | newTime `isDiffLessThan2Secs` lastT -> State TwoClicks (Just newTime)
        | otherwise                           -> State OneClick (Just newTime)
    
      (TwoClicks, Just lastT)
        | newTime `isDiffLessThan2Secs` lastT -> State ThreeClicks (Just newTime)
        | otherwise                           -> State OneClick (Just newTime)
    
      (ThreeClicks, _) -> 
        State ZeroClicks Nothing
    
      _ -> State OneClick (Just newTime)
-}

updateState :: UTCTime -> State -> State
updateState newTime state = case (clickCounts state, clickTime state) of
      -- 1er Clic: Guardamos el tiempo inicial (el inicio del combo)
      (ZeroClicks, _) -> 
        State OneClick (Just newTime)
    
      -- 2do Clic: Comparamos con el primer tiempo y LO MANTENEMOS (Just firstT)
      (OneClick, Just firstT)
        | newTime `isDiffLessThan2Secs` firstT -> State TwoClicks (Just firstT) 
        | otherwise                            -> State OneClick (Just newTime)
    
      -- 3er Clic: Comparamos con el primer tiempo almacenado
      (TwoClicks, Just firstT)
        | newTime `isDiffLessThan2Secs` firstT -> State ThreeClicks (Just newTime)
        | otherwise                            -> State OneClick (Just newTime)
    
      -- 4to Clic: Si ya está en ThreeClicks (desbloqueado), cualquier clic lo bloquea
      (ThreeClicks, _) -> 
        State ZeroClicks Nothing
    
      -- Caso de seguridad (catch-all)
      _ -> State OneClick (Just newTime)        

-------------------------------------------------
-- LED 
-------------------------------------------------
ledOffset :: LineOffset
ledOffset = LineOffset 256 

ledSettings :: LineSettings -> IO()
ledSettings settings = do
  setDirection settings DirOutput

ledWorker :: LineRequest -> MVar State -> IO()
ledWorker request buzon = do
  state <- readMVar buzon
  let numOfClicks = clickCounts state  
  case numOfClicks of
    ThreeClicks -> setValue request ledOffset LineActive
    ZeroClicks  -> setValue request ledOffset LineInactive 
    _           -> return ()                   
  threadDelay 100000

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
btnWorker request buffer buzon = do
  res <- waitEdgeEvents request oneSecondNs
  case res of
     EventsReady readyReq  -> do
       _ <- readEdgeEvents readyReq buffer
       newTime <- getCurrentTime
       putStrLn "\n=========================================="
       putStrLn "💥 [BOTÓN] ¡Pulsación detectada!"
       oldState <- readMVar buzon
       let newState = updateState newTime oldState
       putStrLn $ "   ⏱️ Hora del clic: " ++ show newTime
       putStrLn $ "   ◀️ Estado anterior: " ++ show oldState
       putStrLn $ "   ▶️ Estado nuevo:    " ++ show newState
       putStrLn "==========================================\n"
       modifyMVar_ buzon (\_ -> return newState) 
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
  runApp `catch` handleExit
  where
    handleExit :: IOException -> IO ()
    handleExit err = putStrLn ("\n¡Programa finalizado limpiamente!" ++ show err)
  

runApp :: IO()
runApp = do
  putStrLn "INICIANDO"
  initialBuzon <- newMVar initialState
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
              forever $ btnWorker request buffer initialBuzon  
