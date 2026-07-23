module Main where
import Fuyu.GPIO
import Control.Monad (forever, replicateM_)
import Control.Exception (catch, IOException)
import Control.Concurrent (threadDelay, forkIO, Chan, newChan, readChan, writeChan)
import Data.List.NonEmpty (NonEmpty(..))

-- Combina dos acciones IO en una sola que devuelve una tupla
pairIO :: IO a -> IO b -> IO (a, b)
pairIO = liftA2 (,)

{-
 ### 🥊 Reto 1: Pulsación Corta vs. Pulsación Larga (Short Press vs. Long Press)

  Dificultad: 🟡 Intermedio

  • Objetivo: Diferenciar la duración de la pulsación del botón usando el tiempo transcurrido entre la llegada de 3.3V y la caída a 0V.
  • Comportamiento:
      • Pulsación Corta (<1 segundo): Conmuta el LED (Encender / Apagar).
      • Pulsación Larga (>1 segundo): El LED parpadea 3 veces rápidamente como confirmación.
  • Pista:
  Configura EdgeBoth. En EventRisingEdge guarda el tiempo actual (getCurrentTime de Data.Time.Clock o el timestamp del EdgeEvent), y en EventFallingEdge calcula la diferencia de tiempo transcurrida.
-}

data TimeDuration = Short | Long deriving (Show)

type Nanoseconds = Integer 

esPulsacionCorta :: Nanoseconds -> Nanoseconds -> Bool
esPulsacionCorta n1 n2 = max n1 n2 - min n1 n2 < 1000000000

esRebote :: Nanoseconds -> Nanoseconds -> Bool
esRebote tiempoAnterior tiempoActual =
    let diferencia = tiempoActual - tiempoAnterior
    in diferencia < 50000000 -- Si pasaron menos de 50 milisegundos, es un rebote

chipPath :: FilePath
chipPath = "/dev/gpiochip0"

pinLED :: LineOffset
pinLED = LineOffset 256
    
pinButton :: LineOffset
pinButton = LineOffset 271
 
bufferCapacity :: EventBufferCapacity
bufferCapacity = EventBufferCapacity 1
    
fiveNanoseconds :: TimeoutNs
fiveNanoseconds = Nanoseconds 5000000000 -- 5 segundos

led :: LineRequest -> TimeDuration -> IO()
led request td = do
  case td of
    Short -> do setValue request pinLED LineActive
                threadDelay 500000
                setValue request pinLED LineInactive
    Long  -> do replicateM_ 3 $ do
                  putStrLn "blink"
                  setValue request pinLED LineActive
                  threadDelay 100000
                  setValue request pinLED LineInactive
                  threadDelay 100000
  
button :: LineRequest -> EventBuffer -> Chan TimeDuration -> IO ()
button request buffer chan = do
  req <- waitEdgeEvents request fiveNanoseconds
  case req of 
    EventsReady readyReq -> handleButtonEvents readyReq buffer chan
    Timeout              -> return ()  


handleButtonEvents :: ReadyRequest -> EventBuffer -> Chan TimeDuration -> IO ()
handleButtonEvents req buffer chan = do 
    (tipo1, TimestampNs tiempo1) <- waitNextEvent req buffer 
    (tipo2, TimestampNs tiempo2) <- waitNextEvent req buffer 
    case (tipo1, tipo2) of
        (EventRising, EventFalling) -> do
            let timeduration = evaluatePressDuration (fromIntegral tiempo1) (fromIntegral tiempo2)
            print timeduration
            writeChan chan timeduration
                                    
        _ -> putStrLn "Advertencia: Secuencia de eventos inesperada, ignorando par."
        
evaluatePressDuration :: Nanoseconds -> Nanoseconds -> TimeDuration
evaluatePressDuration t1 t2  
  | esPulsacionCorta t1 t2 = Short 
  | otherwise              = Long  
  

waitNextEvent :: ReadyRequest -> EventBuffer -> IO (EdgeEventType, TimestampNs)
waitNextEvent readyReq buffer = do
  let req = readyToLineRequest readyReq
  record <- withRawEdgeEvents readyReq buffer $ \raw -> do  
    let e = getRawEventType raw 
    let t = getRawTimestampNs raw  
    pairIO e t
  case record of
    r :| [] -> return r   
    _       -> do
      waitRes <- waitEdgeEvents req fiveNanoseconds
      case waitRes of
        EventsReady newReadyReq -> waitNextEvent newReadyReq buffer
        Timeout                 -> ioError (userError "waitNextEvent: Timeout esperando el siguiente evento del botón")
     
main :: IO()
main = do
  runApp `catch` handleExit
  where
    handleExit :: IOException -> IO ()
    handleExit _ = putStrLn "\n¡Programa finalizado limpiamente!"

-- | Limpia y descarta eventos iniciales o residuales que hayan quedado al configurar la línea GPIO.
flushInitialEvents :: LineRequest -> EventBuffer -> IO ()
flushInitialEvents request buffer = do
  res <- waitEdgeEvents request (Nanoseconds 0)
  case res of
    EventsReady readyReq -> do
      _ <- readEdgeEvents readyReq buffer
      flushInitialEvents request buffer -- Limpia de forma recursiva si hay varios en ráfaga
    Timeout -> return ()
    
runApp :: IO()
runApp = do 
  -- Chip
  withChip chipPath $ \chip -> do
    -- Button settings
    withLineSettings $ \btnSettings -> do
      setDirection btnSettings DirInput  
      setBias btnSettings BiasPullDown
      setEdgeDetection btnSettings EdgeBoth
      
      -- Led settings
      withLineSettings $ \ledSettings -> do
      
        -- Global config 
        withLineConfig $ \config -> do
          addConfigToLineSettings config [pinButton] btnSettings
          addConfigToLineSettings config [pinLED] ledSettings
          setDirection ledSettings DirOutput

          -- Button request
          withLineRequest chip Nothing config $ \btnRequest -> do  
            withEdgeEventBuffer bufferCapacity $ \buffer -> do
              flushInitialEvents btnRequest buffer -- 🧹 Limpia cualquier basura inicial del kernel
              chan <- newChan
              _ <- forkIO $ forever $ do
                td <- readChan chan
                led btnRequest td
              putStrLn "Esperando la primera pulsación (sin límite de tiempo)..."
              forever $ button btnRequest buffer chan
