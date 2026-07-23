module Main where

import Fuyu.GPIO

chipPath :: FilePath
chipPath = "/dev/gpiochip0" 

main :: IO()
main = do
  withChip chipPath $ \chip ->
    withChipInfo chip $ \chipInfo -> do
      chipName <- getChipName chipInfo
      chipLabel <- getChipLabel chipInfo
      numLines <- getChipNumLines chipInfo

      putStrLn chipName      
      putStrLn chipLabel 
      print numLines
  
