module Main where

import Fuyu.GPIO
import Control.Concurrent (threadDelay, newMVar, modifyMVar, MVar, forkIO, newEmptyMVar, takeMVar)
import Control.Monad (forever)
import Control.Exception (catch, IOException, SomeException)
import System.IO (hSetBuffering, stdout, BufferMode(LineBuffering))

-- =====================================================================
-- 1. TIPOS DE DATOS Y CONFIGURACIÓN CONSTANTE
-- =====================================================================

data LedState = Off | On deriving (Eq, Show)

toggle :: LedState -> LedState
toggle Off = On
toggle On  = Off

chipPath :: FilePath
chipPath = "/dev/gpiochip0"

pinLED :: LineOffset
pinLED = LineOffset 256

pinButton :: LineOffset
pinButton = LineOffset 271

bufferCapacity :: EventBufferCapacity
bufferCapacity = EventBufferCapacity 10

nanoseconds :: TimeoutNs
nanoseconds = Nanoseconds 5000000000 -- 5 segundos

-- =====================================================================
-- 2. CONFIGURACIÓN Y SOLICITUD DE RECURSOS (Se ejecuta 1 sola vez)
-- =====================================================================

withButtonSettings :: (LineSettings -> IO a) -> IO a
withButtonSettings action = withLineSettings $ \s -> do
  setDirection s DirInput
  setBias s BiasPullDown
  setEdgeDetection s EdgeRising
  action s

withLedSettings :: (LineSettings -> IO a) -> IO a
withLedSettings action = withLineSettings $ \s -> do
  setDirection s DirOutput
  action s

withCombinedConfig :: [LineOffset] -> [LineOffset] -> (LineConfig -> IO a) -> IO a
withCombinedConfig buttonPins ledPins action =
  withButtonSettings $ \btnSettings ->
    withLedSettings $ \ledSettings ->
      withLineConfig $ \config -> do
        addConfigToLineSettings config buttonPins btnSettings
        addConfigToLineSettings config ledPins ledSettings
        action config

-- Crea la solicitud maestra (LineRequest) una sola vez
withControllerRequest :: String -> [LineOffset] -> [LineOffset] -> (LineRequest -> IO a) -> IO a
withControllerRequest path buttonPins ledPins action =
  withChip path $ \chip ->
    withCombinedConfig buttonPins ledPins $ \config ->
      withLineRequest chip Nothing config action

-- =====================================================================
-- 3. LÓGICA DE NEGOCIO Y BUCLE EN HILO SECUNDARIO (forkIO)
-- =====================================================================

handleButtonPress :: LineRequest -> MVar LedState -> IO ()
handleButtonPress request estadoLed = do
  nuevoEstado <- modifyMVar estadoLed $ \st -> do
    let nxt = toggle st
    return (nxt, nxt)
  
  case nuevoEstado of
    On -> do
      setValue request pinLED LineActive
      putStrLn "-> [Hilo Secundario] 3.3V Detectados -> LED ENCENDIDO"
    Off -> do
      setValue request pinLED LineInactive
      putStrLn "-> [Hilo Secundario] 3.3V Detectados -> LED APAGADO"

  threadDelay 200000 -- Antirrebote

-- Bucle de eventos que se ejecutará en background dentro del forkIO
buttonWorkerLoop :: LineRequest -> EventBuffer -> MVar LedState -> IO ()
buttonWorkerLoop request buffer estadoLed =
  (forever $ do
    result <- waitEdgeEvents request nanoseconds
    case result of
      EventsReady readyReq -> do
        _events <- readEdgeEvents readyReq buffer
        handleButtonPress request estadoLed
      Timeout -> return ()
  ) `catch` handleWorkerExit
  where
    handleWorkerExit :: SomeException -> IO ()
    handleWorkerExit _ = return () -- Capturar la interrupción del hilo secundario en silencio

-- =====================================================================
-- 4. PUNTO DE ENTRADA CON MULTIHILO (forkIO)
-- =====================================================================

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  putStrLn "=== CONTROL MULTIHILO (forkIO) DE GPIO ==="
  putStrLn "Presiona el botón en pin 271 para encender/apagar el LED en pin 256."
  putStrLn "Presiona Ctrl+C para salir."

  runApp `catch` handleMainExit
  where
    handleMainExit :: IOException -> IO ()
    handleMainExit _ = putStrLn "\n¡Programa finalizado limpiamente!"

runApp :: IO ()
runApp = do
  estadoLed <- newMVar Off
  exitSignal <- newEmptyMVar

  withControllerRequest chipPath [pinButton] [pinLED] $ \request -> do
    setValue request pinLED LineInactive

    withEdgeEventBuffer bufferCapacity $ \buffer -> do
      _ <- forkIO $ buttonWorkerLoop request buffer estadoLed

      putStrLn "[Hilo Principal] Worker del botón lanzado en background con forkIO."
      putStrLn "[Hilo Principal] El hilo principal queda libre/esperando sin consumir CPU..."

      takeMVar exitSignal
