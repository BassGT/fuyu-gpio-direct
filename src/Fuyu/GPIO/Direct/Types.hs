{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Fuyu.GPIO.Direct.Types where

import Foreign.Ptr (Ptr)
import Foreign.C.Types (CInt(..))
import Data.Word (Word64)
import Data.Int (Int64)

--------------------------------------------------------------------------------
-- CORE TYPES & WRAPPERS
--------------------------------------------------------------------------------

-- | Opaque ghost types representing the C structs from libgpiod.
data CGpiodChip 
data CGpiodChipInfo
data CGpiodInfoEvent
data CGpiodLineInfo 
data CGpiodLineSettings  
data CGpiodLineClock 
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

--------------------------------------------------------------------------------
-- LINE DEFINITIONS TYPES
--------------------------------------------------------------------------------

-- | Gpiod line definitions (C enum) as Haskell Types, see [libgpiod docs](https://libgpiod.readthedocs.io/en/master/core_line_defs.html#).

-- | ADT representing the logical line state. 
data LineValue = LineActive   -- ^ Line is logically active (1 as C int).
               | LineInactive -- ^ Line is logically inactive (0 as C int). 
               | LineError    -- ^ Returned to indicate an error when reading the value (-1 as C int).
               | LineOther CInt -- ^ Fallback constructor for unmapped C int values.
               deriving (Eq, Ord, Show, Read)

-- | ADT representing direction settings.  
data LineDirection = DirAsIs   -- ^ Request the line(s), but don't change direction (1 as C int).  
                   | DirInput  -- ^ For reading the value of an externally driven GPIO line (2 as C int).
                   | DirOutput -- ^ For driving the GPIO line (3 as C int).
                   | DirOther CInt -- ^ Fallback constructor for unmapped C int values.
                   deriving (Eq, Ord, Show, Read)

-- | ADT representing edge detection settings. 
data LineEdge = EdgeNone    -- ^ Line edge detection is disabled (1 as C int). 
              | EdgeRising  -- ^ Line detects rising edge events (2 as C int). 
              | EdgeFalling -- ^ Line detects falling edge events (3 as C int). 
              | EdgeBoth    -- ^ Line detects both rising and falling edge events (4 as C int). 
              | EdgeOther CInt -- ^ Fallback constructor for unmapped C int values.
              deriving (Eq, Ord, Show, Read)

-- | ADT representing internal line bias settings. 
data LineBias = BiasAsIs     -- ^ Don't change the bias setting when applying line config (1 as C int). 
              | BiasUnknown  -- ^ The internal bias state is unknown (2 as C int). 
              | BiasDisabled -- ^ The internal bias is disabled (3 as C int). 
              | BiasPullUp   -- ^ The internal pull-up bias is enabled (4 as C int).
              | BiasPullDown -- ^ The internal pull-down bias is enabled (5 as C int). 
              | BiasOther CInt -- ^ Fallback constructor for unmapped C int values.
              deriving (Eq, Ord, Show, Read)

-- | ADT representing output drive settings.
data LineDrive = PushPull   -- ^ Drive setting is push-pull (1 as C int). 
               | OpenDrain  -- ^ Line output is open-drain (2 as C int). 
               | OpenSource -- ^ Line output is open-source (3 as C int). 
               | DriveOther CInt -- ^ Fallback constructor for unmapped C int values.
               deriving (Eq, Ord, Show, Read)

-- | ADT representing line clock settings. 
data LineClock = Monotonic -- ^ Line uses the monotonic clock for edge event timestamps (1 as C int).
               | Realtime  -- ^ Line uses the realtime clock for edge event timestamps (2 as C int).
               | Hardware  -- ^ Line uses the hardware timestamp engine for event timestamps (3 as C int). 
               | ClockOther CInt -- ^ Fallback constructor for unmapped C int values.
               deriving (Eq, Ord, Show, Read)

--------------------------------------------------------------------------------
-- OTHER LIBGPIOD DEFINITIONS TYPES
--------------------------------------------------------------------------------
data InfoEventType = LineRequested     -- ^ Line has been requested (1 as C int). 
                   | LineReleased      -- ^ Line has been released (2 as C int).
                   | LineConfigChanged -- ^ Line configuration has changed (3 as C int).
                   | InfoEventOther CInt -- ^ Fallback constructor for unmapped C int values. 
                   deriving (Eq, Ord, Show, Read)

-- | ADT representing the type of edge event detected.
data EdgeEventType  = Rising  -- ^ Event triggered on a rising edge (1 as C int).
                    | Falling -- ^ Event triggered on a falling edge (2 as C int).
                    | EventOther CInt -- ^ Fallback constructor for unmapped C int values.
                    deriving (Eq, Ord, Show, Read)
  
--------------------------------------------------------------------------------
-- NATIVE HELPER TYPES 
--------------------------------------------------------------------------------
data WaitResult 
  = Timeout
  | EventReady 
  deriving (Eq, Ord, Show, Read)

data TimeoutNs = Nanoseconds Word64
               | Immediate
               | Infinite 
               deriving (Eq, Ord, Show, Read)

newtype TimestampNs = TimestampNs Word64
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)

data EdgeEvent = EdgeEvent 
  { eventLineOffset :: LineOffset
  , edgeType        :: EdgeEventType
  , timestamp       :: TimestampNs 
  } deriving (Eq, Ord, Show, Read)

