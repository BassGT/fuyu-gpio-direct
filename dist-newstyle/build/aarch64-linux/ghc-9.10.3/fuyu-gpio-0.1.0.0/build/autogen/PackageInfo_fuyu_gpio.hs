{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module PackageInfo_fuyu_gpio (
    name,
    version,
    synopsis,
    copyright,
    homepage,
  ) where

import Data.Version (Version(..))
import Prelude

name :: String
name = "fuyu_gpio"
version :: Version
version = Version [0,1,0,0] []

synopsis :: String
synopsis = "Bindings para libgpiod en Haskell."
copyright :: String
copyright = ""
homepage :: String
homepage = ""
