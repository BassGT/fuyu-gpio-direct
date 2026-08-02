{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}
-- |
-- Module      : Fuyu.GPIO.Direct.Types
-- Description : Core data types, newtype wrappers, and C enum pattern synonyms for libgpiod v2 bindings.
-- Maintainer  : BassGT
-- Portability : POSIX (Linux GPIO character device interface)
--
-- This module defines all data types, opaque handles, safety wrappers, pattern
-- synonyms for C enums, and native helper structures used throughout the
-- @fuyu-gpio-direct@ library.
--
-- Resource handles wrap raw foreign pointers to C structures managed by @libgpiod v2@.
-- Callers are responsible for explicitly freeing handles created via allocations or getters
-- using their corresponding cleanup operations (e.g., 'Fuyu.GPIO.Direct.chipClose',
-- 'Fuyu.GPIO.Direct.lineSettingsFree', etc.).
module Fuyu.GPIO.Direct.Types where

import Foreign.Ptr (Ptr)
import Foreign.Storable (Storable)
import Data.Word (Word64)
import Foreign.C.Types (CInt(..), CUInt(..), CULong(..))

--------------------------------------------------------------------------------
-- CORE TYPES & WRAPPERS
--------------------------------------------------------------------------------

-- | Opaque ghost type representing the C structure @struct gpiod_chip@.
data CGpiodChip 

-- | Opaque ghost type representing the C structure @struct gpiod_chip_info@.
data CGpiodChipInfo

-- | Opaque ghost type representing the C structure @struct gpiod_info_event@.
data CGpiodInfoEvent

-- | Opaque ghost type representing the C structure @struct gpiod_line_info@.
data CGpiodLineInfo 

-- | Opaque ghost type representing the C structure @struct gpiod_line_settings@.
data CGpiodLineSettings  

-- | Opaque ghost type representing the C structure @struct gpiod_line_config@.
data CGpiodLineConfig  

-- | Opaque ghost type representing the C structure @struct gpiod_line_request@.
data CGpiodLineRequest    

-- | Opaque ghost type representing the C structure @struct gpiod_request_config@.
data CGpiodRequestConfig

-- | Opaque ghost type representing the C structure @struct gpiod_edge_event_buffer@.
data CGpiodEdgeEventBuffer

-- | Opaque ghost type representing the C structure @struct gpiod_edge_event@.
data CGpiodEdgeEvent

-- | Opaque handle representing an open GPIO chip device controller.
--
-- Must be explicitly closed with 'Fuyu.GPIO.Direct.chipClose' when no longer needed.
newtype Chip = Chip (Ptr CGpiodChip)
  deriving (Eq, Ord, Show)

-- | Opaque snapshot of static GPIO chip information (name, label, line count).
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.chipInfoFree'.
newtype ChipInfo = ChipInfo (Ptr CGpiodChipInfo)
  deriving (Eq, Ord, Show)

-- | Opaque event object emitted when a line watched on a chip changes status.
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.infoEventFree'.
newtype InfoEvent = InfoEvent (Ptr CGpiodInfoEvent)
  deriving (Eq, Ord, Show)

-- | Opaque snapshot of a single GPIO line\'s status and configuration attributes.
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.lineInfoFree'.
newtype LineInfo = LineInfo (Ptr CGpiodLineInfo)
  deriving (Eq, Ord, Show)

-- | Opaque accumulator for GPIO line configuration settings (direction, drive, bias, etc.).
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.lineSettingsFree'.
newtype LineSettings = LineSettings (Ptr CGpiodLineSettings)
  deriving (Eq, Ord, Show)

-- | Opaque map associating line offsets with their respective t'LineSettings.
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.lineConfigFree'.
newtype LineConfig = LineConfig (Ptr CGpiodLineConfig)
  deriving (Eq, Ord, Show)

-- | Opaque handle representing requested (claimed) GPIO lines under active kernel control.
--
-- Must be explicitly released with 'Fuyu.GPIO.Direct.lineRequestRelease'.
newtype LineRequest = LineRequest (Ptr CGpiodLineRequest)
  deriving (Eq, Ord, Show)

-- | Opaque request configuration object (consumer name, kernel event buffer size).
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.requestConfigFree'.
newtype RequestConfig = RequestConfig (Ptr CGpiodRequestConfig)
  deriving (Eq, Ord, Show)

-- | Opaque fixed-capacity buffer storing edge detection events read from the kernel.
--
-- Must be explicitly freed with 'Fuyu.GPIO.Direct.eventBufferFree'.
newtype EventBuffer = EventBuffer (Ptr CGpiodEdgeEventBuffer) 
  deriving (Eq, Ord, Show)

-- | Opaque reference to an individual edge detection event stored within an t'EventBuffer.
--
-- Can be copied using 'Fuyu.GPIO.Direct.rawEdgeEventCopy', which returned copy must be freed
-- via 'Fuyu.GPIO.Direct.rawEdgeEventFree'.
newtype RawEdgeEvent = RawEdgeEvent (Ptr CGpiodEdgeEvent)
  deriving (Eq, Ord, Show)

-- | Type-safe wrapper for zero-based GPIO line offset indices on a chip.
newtype LineOffset = LineOffset CUInt
  deriving (Eq, Ord, Show, Read, Storable)



--------------------------------------------------------------------------------
-- LINE DEFINITIONS TYPES
--------------------------------------------------------------------------------

-- | Logical line state representation.
--
-- Note that logical values account for active-low inversion: an active-low line set to
-- 'LineActive' corresponds to a physical logic low voltage level on hardware.
newtype LineValue = LineValue CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Logical active state (1).
pattern LineActive :: LineValue
pattern LineActive = LineValue 1

-- | Logical inactive state (0).
pattern LineInactive :: LineValue
pattern LineInactive = LineValue 0

-- | Error sentinel returned by low-level functions on failure (-1).
pattern LineError :: LineValue
pattern LineError = LineValue (-1)

{-# COMPLETE LineActive, LineInactive, LineError, LineValue #-}

-- | GPIO line pin direction configuration.
newtype LineDirection = LineDirection CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Leave line direction unchanged during configuration re-application.
pattern DirAsIs :: LineDirection
pattern DirAsIs = LineDirection 1

-- | Configure line as input.
pattern DirInput :: LineDirection
pattern DirInput = LineDirection 2

-- | Configure line as output.
pattern DirOutput :: LineDirection
pattern DirOutput = LineDirection 3

{-# COMPLETE DirAsIs, DirInput, DirOutput, LineDirection #-}

-- | Edge detection mode for monitoring input signal transitions.
newtype LineEdge = LineEdge CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Disable edge detection events on this line.
pattern EdgeNone :: LineEdge
pattern EdgeNone = LineEdge 1

-- | Trigger edge events on low-to-high (rising) signal transitions.
pattern EdgeRising :: LineEdge
pattern EdgeRising = LineEdge 2

-- | Trigger edge events on high-to-low (falling) signal transitions.
pattern EdgeFalling :: LineEdge
pattern EdgeFalling = LineEdge 3

-- | Trigger edge events on both rising and falling signal transitions.
pattern EdgeBoth :: LineEdge
pattern EdgeBoth = LineEdge 4

{-# COMPLETE EdgeNone, EdgeRising, EdgeFalling, EdgeBoth, LineEdge #-}

-- | Internal pull resistor bias configuration for a line.
newtype LineBias = LineBias CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Keep current line bias settings unchanged.
pattern BiasAsIs :: LineBias
pattern BiasAsIs = LineBias 1

-- | Line bias is unknown or non-standard.
pattern BiasUnknown :: LineBias
pattern BiasUnknown = LineBias 2

-- | Disable internal pull-up and pull-down resistors (floating input / tri-stated).
pattern BiasDisabled :: LineBias
pattern BiasDisabled = LineBias 3

-- | Enable internal pull-up resistor.
pattern BiasPullUp :: LineBias
pattern BiasPullUp = LineBias 4

-- | Enable internal pull-down resistor.
pattern BiasPullDown :: LineBias
pattern BiasPullDown = LineBias 5

{-# COMPLETE BiasAsIs, BiasUnknown, BiasDisabled, BiasPullUp, BiasPullDown, LineBias #-}

-- | Output pin driver mode configuration.
newtype LineDrive = LineDrive CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Standard push-pull driver actively driving high and low output logic levels.
pattern PushPull :: LineDrive
pattern PushPull = LineDrive 1

-- | Open-drain driver mode (sinks current when active, open/high-impedance when inactive).
pattern OpenDrain :: LineDrive
pattern OpenDrain = LineDrive 2

-- | Open-source driver mode (sources current when active, open/high-impedance when inactive).
pattern OpenSource :: LineDrive
pattern OpenSource = LineDrive 3

{-# COMPLETE PushPull, OpenDrain, OpenSource, LineDrive #-}

-- | Timestamp clock source used when recording line edge events in the kernel.
newtype LineClock = LineClock CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Kernel @CLOCK_MONOTONIC@ clock source (default).
pattern Monotonic :: LineClock
pattern Monotonic = LineClock 1

-- | Kernel @CLOCK_REALTIME@ wall-clock source.
pattern Realtime :: LineClock
pattern Realtime = LineClock 2

-- | Hardware SoC timestamp clock source (if supported by hardware/kernel).
pattern Hardware :: LineClock
pattern Hardware = LineClock 3

{-# COMPLETE Monotonic, Realtime, Hardware, LineClock #-}

--------------------------------------------------------------------------------
-- OTHER LIBGPIOD DEFINITIONS TYPES
--------------------------------------------------------------------------------

-- | Type of status change event emitted when watching line status on a GPIO chip.
newtype InfoEventType = InfoEventType CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Line was claimed / requested by a process consumer.
pattern LineRequested :: InfoEventType
pattern LineRequested = InfoEventType 1

-- | Line was released by its consumer process.
pattern LineReleased :: InfoEventType
pattern LineReleased = InfoEventType 2

-- | Line configuration attributes were modified.
pattern LineConfigChanged :: InfoEventType
pattern LineConfigChanged = InfoEventType 3

{-# COMPLETE LineRequested, LineReleased, LineConfigChanged, InfoEventType #-}

-- | Direction of transition detected on an input edge event.
newtype EdgeEventType = EdgeEventType CInt
  deriving (Eq, Ord, Show, Read, Storable)

-- | Low-to-high transition detected.
pattern Rising :: EdgeEventType
pattern Rising = EdgeEventType 1

-- | High-to-low transition detected.
pattern Falling :: EdgeEventType
pattern Falling = EdgeEventType 2

{-# COMPLETE Rising, Falling, EdgeEventType #-}

--------------------------------------------------------------------------------
-- NATIVE HELPER TYPES 
--------------------------------------------------------------------------------

-- | Result status of waiting on GPIO chip or line request events.
data WaitResult 
  = Timeout    -- ^ The specified timeout expired before any event arrived.
  | EventReady -- ^ One or more events are ready to be read.
  deriving (Eq, Ord, Show, Read)

-- | Timeout duration configuration for event waiting calls.
data TimeoutNs
  = Nanoseconds CULong -- ^ Wait for up to the specified duration in nanoseconds.
  | Immediate          -- ^ Non-blocking poll; return status immediately.
  | Infinite           -- ^ Block indefinitely until an event arrives (-1 in C API).
  deriving (Eq, Ord, Show, Read)

-- | Absolute timestamp represented in nanoseconds.
type TimestampNs = Word64

-- | Pure Haskell structure containing parsed edge event information.
data EdgeEvent = EdgeEvent 
  { eventLineOffset :: LineOffset   -- ^ Offset index of the line that generated the edge event.
  , edgeType        :: EdgeEventType -- ^ Type of edge transition ('Rising' or 'Falling').
  , timestamp       :: TimestampNs   -- ^ Event timestamp in nanoseconds.
  } deriving (Eq, Ord, Show, Read)
