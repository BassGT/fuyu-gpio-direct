module Main where

import qualified Fuyu.GPIO as F 
import Fuyu.GPIO (Direction(..), LineOffset(..), LineValue(..))
import Control.Concurrent (threadDelay)
import Control.Monad (replicateM_)

chipPath :: FilePath 
chipPath = "/dev/gpiochip0"  

pines :: [LineOffset]
pines = [LineOffset 256]

pin :: LineOffset
pin = LineOffset 256  

main :: IO()
main = do
  F.withChip chipPath $ \chip -> do
    F.withLineSettings $ \settings -> do 
      F.setDirection settings DirOutput
      F.withLineConfig $ \config -> do
        F.addConfigToLineSettings config pines settings
        F.withLineRequest chip Nothing config $ \request -> do
          replicateM_ 10 $ do  
            putStrLn "LED prendido" 
            F.setValue request pin LineActive
            threadDelay 1000000
          
            putStrLn "LED apagado" 
            F.setValue request pin LineInactive
            threadDelay 1000000
