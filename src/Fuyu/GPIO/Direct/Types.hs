{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Fuyu.GPIO.Direct.Types where

import Foreign.Ptr (Ptr)
import Data.Word (Word64)
import Data.Int (Int64)

--------------------------------------------------------------------------------
-- 1. CORE TYPES & WRAPPERS
--------------------------------------------------------------------------------

-- | Opaque ghost types representing the C structs from libgpiod.
data CGpiodChip 
data CGpiodChipInfo
data CGpiodInfoEvent
data CGpiodLineInfo 
data CGpiodLineSettings  
data CGpiodLineConfig  
data CGpiodLineRequest    
data CGpiodRequestConfig
data CGpiodEdgeEventBuffer
data CGpiodEdgeEvent

-- | Haskell wrappers around raw C pointers (unmanaged).
newtype Chip = Chip (Ptr CGpiodChip)
  deriving (Eq, Ord, Show)
newtype ChipInfo = ChipInfo (Ptr CGpiodChipInfo)
  deriving (Eq, Ord, Show)
newtype InfoEvent = InfoEvent (Ptr CGpiodInfoEvent)
  deriving (Eq, Ord, Show)
newtype LineInfo = LineInfo (Ptr CGpiodLineInfo)
  deriving (Eq, Ord, Show)
newtype LineSettings = LineSettings (Ptr CGpiodLineSettings)
  deriving (Eq, Ord, Show)
newtype LineConfig = LineConfig (Ptr CGpiodLineConfig)
  deriving (Eq, Ord, Show)
newtype LineRequest = LineRequest (Ptr CGpiodLineRequest)
  deriving (Eq, Ord, Show)
newtype RequestConfig = RequestConfig (Ptr CGpiodRequestConfig)
  deriving (Eq, Ord, Show)
data EventBuffer = EventBuffer (Ptr CGpiodEdgeEventBuffer) EventBufferCapacity 
  deriving (Eq, Ord, Show)
newtype RawEdgeEvent = RawEdgeEvent (Ptr CGpiodEdgeEvent)
  deriving (Eq, Ord, Show)

-- | Safety wrappers for type-safe APIs.
newtype LineOffset = LineOffset Word
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)
newtype EventBufferCapacity = EventBufferCapacity Word
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)
newtype BufferIndex = BufferIndex Word64
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)

-- | Token indicating that a request has events ready to be read.
newtype ReadyRequest = ReadyRequest (Ptr CGpiodLineRequest)
  deriving (Eq, Ord, Show)

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

data TimeoutNs = Nanoseconds Int64
               | Immediate
               | Infinite 
               deriving (Eq, Ord, Show, Read)

data WaitResult 
  = Timeout
  | EventReady 
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

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
