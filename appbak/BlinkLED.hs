module Main where

import Fuyu.GPIO.V1
import Control.Concurrent (threadDelay)
import Control.Monad (unless)

chipName :: String
chipName = "gpiochip0"

lineNum :: Int
lineNum = 269

blink :: GpioLine -> IO()
blink line = do
  putStrLn "LED prendido!"
  valueFlag1 <- setValue line High
  unless valueFlag1 $ error "No se puede modificar estado del LED"    
  threadDelay 1000000
  
  putStrLn "LED apagado!"
  valueFlag2 <- setValue line Low 
  unless valueFlag2 $ error "No se puede modificar estado del LED"
  threadDelay 1000000
  blink line 

main :: IO ()
main = do
   maybeChip <- openChipByName chipName
   case maybeChip of
     Nothing -> error "No se pudo abrir el controlador GPIO"
     Just chip -> do
       withOutputLine chip lineNum "Ejemplo_Haskell" Low blink 
