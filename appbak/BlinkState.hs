module Main where

import Fuyu.GPIO.V1
import Control.Concurrent (threadDelay)
import Control.Monad (unless)
import System.IO

data LedState = Off | On

toggle :: LedState -> LedState
toggle Off = On
toggle On  = Off 

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

blink :: GpioLine -> LedState -> IO()
blink line On = do
  putStrLn "LED prendido!"
  valueFlag1 <- setValue line (stateToValue On)
  unless valueFlag1 $ error "No se puede modificar estado del LED"    
  
blink line Off  = do
  putStrLn "LED apagado!"
  valueFlag2 <- setValue line (stateToValue Off)
  unless valueFlag2 $ error "No se puede modificar estado del LED"

buttonLed :: GpioLine -> GpioLine -> Value -> LedState -> IO ()
buttonLed inLine outLine lastValue ledstate = do
  lineState <- getValue inLine  

  case (lineState, lastValue) of
    (Just High, Low) -> do threadDelay 250000
                           blink outLine (toggle ledstate)
                           buttonLed inLine outLine High (toggle ledstate)
    (Just Low, _)    -> do threadDelay 50000
                           buttonLed inLine outLine Low ledstate
    (Nothing, _)     -> error "No se pudo leer correctamente el estado"
    _                -> do threadDelay 250000
                           buttonLed inLine outLine lastValue ledstate
    
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "Ejemplo: blinkAndRead"
  maybeChip <- openChipByName chipName
  case maybeChip of
    Nothing -> error "No se pudo abrir el controlador GPIO"
    Just chip -> do
      withInputLine chip inputLineNum "Boton" $ \inLine -> 
        withOutputLine chip outputLineNum "Led" Low $ \outLine -> do
          putStrLn "Esperando entrada..."
          buttonLed inLine outLine initialValue initialState
