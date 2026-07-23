module Main where

import Fuyu.GPIO.V1
import Control.Concurrent (threadDelay)
import Control.Monad (unless)
import System.IO

chipName :: String
chipName = "gpiochip0"

inputLineNum :: Int 
inputLineNum = 260 -- Pin físico 38 

outputLineNum :: Int 
outputLineNum = 259 -- Pin físico 40 

blink :: GpioLine -> IO()
blink line = do
  putStrLn "LED prendido!"
  valueFlag1 <- setValue line High
  unless valueFlag1 $ error "No se puede modificar estado del LED"    
  threadDelay 1000000
  
  putStrLn "LED apagado!"
  valueFlag2 <- setValue line Low 
  unless valueFlag2 $ error "No se puede modificar estado del LED"

buttonLed :: GpioLine -> GpioLine -> IO ()
buttonLed inLine outLine = do
  putStrLn "Esperando entrada..."
  lineState <- getValue inLine  

  case lineState of
    Just High -> do threadDelay 50000
                    blink outLine
                    buttonLed inLine outLine
                                      
    Just Low  -> do threadDelay 50000
                    buttonLed inLine outLine  
    Nothing   -> error "No se pudo leer correctamente el estado"
    
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "Ejemplo: blinkAndRead"
  maybeChip <- openChipByName chipName
  case maybeChip of
    Nothing -> error "No se pudo abrir el controlador GPIO"
    Just chip -> do
      withInputLine chip inputLineNum "Boton" $ \inLine -> 
        withOutputLine chip outputLineNum "Led" Low $ \outLine -> buttonLed inLine outLine
