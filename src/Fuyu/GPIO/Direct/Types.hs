{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}
module Fuyu.GPIO.Direct.Types where

import Foreign.Ptr (Ptr)
import Foreign.Storable (Storable)
import Foreign.C.Types (CInt(..), CUInt(..), CULong(..), CSize(..))

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
newtype EventBuffer = EventBuffer (Ptr CGpiodEdgeEventBuffer) 
  deriving (Eq, Ord, Show)
newtype RawEdgeEvent = RawEdgeEvent (Ptr CGpiodEdgeEvent)
  deriving (Eq, Ord, Show)

-- | Safety wrappers for type-safe APIs.
newtype LineOffset = LineOffset CUInt
  deriving (Eq, Ord, Show, Read, Storable)
newtype EventBufferCapacity = EventBufferCapacity CSize
  deriving (Eq, Ord, Show, Read, Storable)
newtype BufferIndex = BufferIndex CULong
  deriving (Eq, Ord, Show, Read, Storable)

--------------------------------------------------------------------------------
-- LINE DEFINITIONS TYPES
--------------------------------------------------------------------------------

-- | Gpiod line definitions (C enum) as Haskell Types, see [libgpiod docs](https://libgpiod.readthedocs.io/en/master/core_line_defs.html#).

-- | Newtype representing the logical line state. 
newtype LineValue = LineValue CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern LineActive :: LineValue
pattern LineActive = LineValue 1

pattern LineInactive :: LineValue
pattern LineInactive = LineValue 0

pattern LineError :: LineValue
pattern LineError = LineValue (-1)

{-# COMPLETE LineActive, LineInactive, LineError, LineValue #-}

-- | Newtype representing direction settings.  
newtype LineDirection = LineDirection CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern DirAsIs :: LineDirection
pattern DirAsIs = LineDirection 1

pattern DirInput :: LineDirection
pattern DirInput = LineDirection 2

pattern DirOutput :: LineDirection
pattern DirOutput = LineDirection 3

{-# COMPLETE DirAsIs, DirInput, DirOutput, LineDirection #-}

-- | Newtype representing edge detection settings. 
newtype LineEdge = LineEdge CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern EdgeNone :: LineEdge
pattern EdgeNone = LineEdge 1

pattern EdgeRising :: LineEdge
pattern EdgeRising = LineEdge 2

pattern EdgeFalling :: LineEdge
pattern EdgeFalling = LineEdge 3

pattern EdgeBoth :: LineEdge
pattern EdgeBoth = LineEdge 4

{-# COMPLETE EdgeNone, EdgeRising, EdgeFalling, EdgeBoth, LineEdge #-}

-- | Newtype representing internal line bias settings. 
newtype LineBias = LineBias CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern BiasAsIs :: LineBias
pattern BiasAsIs = LineBias 1

pattern BiasUnknown :: LineBias
pattern BiasUnknown = LineBias 2

pattern BiasDisabled :: LineBias
pattern BiasDisabled = LineBias 3

pattern BiasPullUp :: LineBias
pattern BiasPullUp = LineBias 4

pattern BiasPullDown :: LineBias
pattern BiasPullDown = LineBias 5

{-# COMPLETE BiasAsIs, BiasUnknown, BiasDisabled, BiasPullUp, BiasPullDown, LineBias #-}

-- | Newtype representing output drive settings.
newtype LineDrive = LineDrive CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern PushPull :: LineDrive
pattern PushPull = LineDrive 1

pattern OpenDrain :: LineDrive
pattern OpenDrain = LineDrive 2

pattern OpenSource :: LineDrive
pattern OpenSource = LineDrive 3

{-# COMPLETE PushPull, OpenDrain, OpenSource, LineDrive #-}

-- | Newtype representing line clock settings. 
newtype LineClock = LineClock CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern Monotonic :: LineClock
pattern Monotonic = LineClock 1

pattern Realtime :: LineClock
pattern Realtime = LineClock 2

pattern Hardware :: LineClock
pattern Hardware = LineClock 3

{-# COMPLETE Monotonic, Realtime, Hardware, LineClock #-}

--------------------------------------------------------------------------------
-- OTHER LIBGPIOD DEFINITIONS TYPES
--------------------------------------------------------------------------------
newtype InfoEventType = InfoEventType CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern LineRequested :: InfoEventType
pattern LineRequested = InfoEventType 1

pattern LineReleased :: InfoEventType
pattern LineReleased = InfoEventType 2

pattern LineConfigChanged :: InfoEventType
pattern LineConfigChanged = InfoEventType 3

{-# COMPLETE LineRequested, LineReleased, LineConfigChanged, InfoEventType #-}

-- | Newtype representing the type of edge event detected.
newtype EdgeEventType = EdgeEventType CInt
  deriving (Eq, Ord, Show, Read, Storable)

pattern Rising :: EdgeEventType
pattern Rising = EdgeEventType 1

pattern Falling :: EdgeEventType
pattern Falling = EdgeEventType 2

{-# COMPLETE Rising, Falling, EdgeEventType #-}

--------------------------------------------------------------------------------
-- NATIVE HELPER TYPES 
--------------------------------------------------------------------------------
newtype EventBufferSize = EventBufferSize CSize 
  deriving (Eq, Ord, Show, Read, Storable)

data WaitResult 
  = Timeout
  | EventReady 
  deriving (Eq, Ord, Show, Read)

data TimeoutNs = Nanoseconds CULong
               | Immediate
               | Infinite 
               deriving (Eq, Ord, Show, Read)

newtype TimestampNs = TimestampNs CULong
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral, Storable)

data EdgeEvent = EdgeEvent 
  { eventLineOffset :: LineOffset
  , edgeType        :: EdgeEventType
  , timestamp       :: TimestampNs 
  } deriving (Eq, Ord, Show, Read)
