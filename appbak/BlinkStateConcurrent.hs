module Main where

import Fuyu.GPIO.V1
import Control.Concurrent
  (forkIO,
   threadDelay,
   newMVar,
   MVar(..),
   readMVar,
   modifyMVar_
  )
import Control.Monad (unless)
import System.IO

data LedState = Off | On deriving (Show, Eq)

toggle :: LedState -> LedState
toggle Off = On
toggle On  = Off

-- Asumiendo que Value está definido en tu librería como: data Value = Low | High
stateToValue :: LedState -> Value
stateToValue Off = Low
stateToValue On  = High

chipName :: String
chipName = "gpiochip0"

inputLineNum :: Int 
inputLineNum = 260 -- Pin físico 38 

outputLineNum :: Int 
outputLineNum = 259 -- Pin físico 40 

initialValue :: Value
initialValue = Low

initialState :: LedState
initialState = Off

blinkLoop :: GpioLine -> MVar LedState -> IO ()
blinkLoop line buzon = do
  ledstate <- readMVar buzon
  case ledstate of
    On  -> do 
        putStrLn "LED parpadeando..."
        valueFlag1 <- setValue line (stateToValue On)
        unless valueFlag1 $ error "No se puede encender el LED"
        threadDelay 500000
        valueFlag2 <- setValue line (stateToValue Off)
        unless valueFlag2 $ error "No se puede apagar el LED"
        threadDelay 500000
        blinkLoop line buzon
              
    Off -> do 
        -- putStrLn "LED apagado!" (Comentado para no saturar la consola)
        valueFlag2 <- setValue line (stateToValue Off)
        unless valueFlag2 $ error "No se puede modificar estado del LED"
        threadDelay 10000
        blinkLoop line buzon

buttonLed :: GpioLine -> Value -> MVar LedState -> IO ()
buttonLed inLine lastValue buzon = do
  lineState <- getValue inLine  
  case (lineState, lastValue) of
    (Just High, Low) -> do 
        threadDelay 225000
        modifyMVar_ buzon (return . toggle)
        buttonLed inLine High buzon  
    (Just Low, _)    -> do 
        threadDelay 50000
        buttonLed inLine Low buzon 
    (Nothing, _)     -> error "No se pudo leer correctamente el estado"
    _                -> do 
        threadDelay 225000
        buttonLed inLine lastValue buzon

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "Iniciando: Sistema Concurrente de LED y Botón"
  maybeChip <- openChipByName chipName
  case maybeChip of
    Nothing -> error "No se pudo abrir el controlador GPIO"
    Just chip -> do
      initialBuzon <- newMVar initialState 
      _ <- forkIO $ do
             withOutputLine chip outputLineNum "LED concurrente" initialValue $ \outLine -> 
               blinkLoop outLine initialBuzon
      
      withInputLine chip inputLineNum "Boton" $ \inLine ->
         buttonLed inLine initialValue initialBuzon
