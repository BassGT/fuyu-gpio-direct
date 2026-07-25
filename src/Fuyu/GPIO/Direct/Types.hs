{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Fuyu.GPIO.Direct.Types
  ( -- * 1. CORE TYPES & WRAPPERS
    CGpiodChip
  , CGpiodChipInfo
  , CGpiodLineInfo
  , CGpiodLineSettings
  , CGpiodLineConfig
  , CGpiodLineRequest
  , CGpiodRequestConfig
  , CGpiodEdgeEventBuffer
  , CGpiodEdgeEvent

  , Chip(..)
  , ChipInfo(..)
  , LineInfo(..)
  , LineSettings(..)
  , LineConfig(..)
  , LineRequest(..)
  , RequestConfig(..)
  , EventBuffer(..)
  , RawEdgeEvent(..)
  , LineOffset(..)
  , EventBufferCapacity(..)
  , BufferIndex(..)
  , ReadyRequest(..)
  , Microseconds

  -- * 5. LINE SETTINGS TYPES
  , Direction(..)
  , Bias(..)
  , Edge(..)

  -- * 6. LINE REQUESTS & I/O TYPES
  , LineValue(..)
  , TimeoutNs(..)
  , WaitResult(..)

  -- * 7. EDGE EVENTS & EVENT BUFFER TYPES
  , TimestampNs(..)
  , EdgeEvent(..)
  , EdgeEventType(..)
  ) where

import Foreign.ForeignPtr (ForeignPtr)
import Foreign.Ptr (Ptr)
import Data.Word (Word64)

--------------------------------------------------------------------------------
-- 1. CORE TYPES & WRAPPERS
--------------------------------------------------------------------------------

-- | Opaque ghost types representing the C structs from libgpiod.
data CGpiodChip 
data CGpiodChipInfo
data CGpiodLineInfo 
data CGpiodLineSettings  
data CGpiodLineConfig  
data CGpiodLineRequest    
data CGpiodRequestConfig
data CGpiodEdgeEventBuffer
data CGpiodEdgeEvent

-- | Haskell wrappers around C resources (managed or unmanaged pointers).
newtype Chip = Chip (ForeignPtr CGpiodChip)
newtype ChipInfo = ChipInfo (Ptr CGpiodChipInfo)
  deriving (Eq, Ord, Show)
newtype LineInfo = LineInfo (Ptr CGpiodLineInfo)
newtype LineSettings = LineSettings (Ptr CGpiodLineSettings)
  deriving (Eq, Ord, Show)
newtype LineConfig = LineConfig (Ptr CGpiodLineConfig)
  deriving (Eq, Ord, Show)
newtype LineRequest = LineRequest (ForeignPtr CGpiodLineRequest)
newtype RequestConfig = RequestConfig (Ptr CGpiodRequestConfig)
  deriving (Eq, Ord, Show)
data EventBuffer = EventBuffer (Ptr CGpiodEdgeEventBuffer) EventBufferCapacity 
  deriving (Eq, Ord, Show)
newtype RawEdgeEvent = RawEdgeEvent (Ptr CGpiodEdgeEvent)
  deriving (Eq, Ord, Show)

instance Show Chip where
  show _ = "<Chip>"

instance Show LineRequest where
  show _ = "<LineRequest>"

-- | Safety wrappers for type-safe APIs.
newtype LineOffset = LineOffset Word
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)
newtype EventBufferCapacity = EventBufferCapacity Word
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)
newtype BufferIndex = BufferIndex Word64
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)

-- | Opaque token indicating that a request has events ready to be read.
-- This ensures the user cannot call readEdgeEvents without waiting first.
newtype ReadyRequest = ReadyRequest (ForeignPtr CGpiodLineRequest)
  deriving (Eq)

instance Show ReadyRequest where
  show _ = "<ReadyRequest>"

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION TYPES
--------------------------------------------------------------------------------

type Microseconds = Word

--------------------------------------------------------------------------------
-- 5. LINE SETTINGS TYPES
--------------------------------------------------------------------------------

data Direction 
  = DirAsIs 
  | DirInput 
  | DirOutput 
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

data Bias
  = BiasAsIs
  | BiasUnknown
  | BiasDisabled
  | BiasPullUp
  | BiasPullDown 
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

data Edge
  = EdgeNone
  | EdgeRising
  | EdgeFalling
  | EdgeBoth 
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

--------------------------------------------------------------------------------
-- 6. LINE REQUESTS & I/O TYPES
--------------------------------------------------------------------------------

data LineValue = LineActive | LineInactive | LineError  
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

data TimeoutNs = Nanoseconds Word64 | Infinite 
  deriving (Eq, Ord, Show, Read)

data WaitResult 
  = Timeout
  | EventsReady ReadyRequest 
  deriving (Eq, Show)

--------------------------------------------------------------------------------
-- 7. EDGE EVENTS & EVENT BUFFER TYPES
--------------------------------------------------------------------------------

newtype TimestampNs = TimestampNs Word64
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)

data EdgeEvent = EdgeEvent 
  { eventLineOffset :: LineOffset
  , edgeType        :: EdgeEventType
  , timestamp       :: TimestampNs 
  } deriving (Eq, Ord, Show, Read)

data EdgeEventType 
  = EventRising
  | EventFalling
  deriving (Eq, Ord, Show, Read, Bounded, Enum)
