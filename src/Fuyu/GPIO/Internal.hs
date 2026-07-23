{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Fuyu.GPIO.Internal where

import Control.Exception (bracket)
import Control.Monad (forM)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE
import Data.Word (Word32, Word64)
import Foreign.C.Error
  ( throwErrnoIfMinus1
  , throwErrnoIfMinus1_
  , throwErrnoIfNull
  , throwErrnoPathIfNull
  )
import Foreign.C.String (CString, withCString, peekCString)
import Foreign.C.Types (CInt(..), CLong(..), CSize(..), CUInt(..), CULong(..))
import Foreign.ForeignPtr (ForeignPtr, finalizeForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (FunPtr, Ptr, nullPtr)

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
newtype LineOffset = LineOffset Word32
  deriving (Eq, Ord, Show, Read, Num, Enum, Real, Integral)
newtype EventBufferCapacity = EventBufferCapacity Word32
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
-- 2. CHIP MANAGEMENT
--------------------------------------------------------------------------------

-- --- C FFI Imports ---

foreign import ccall "gpiod_chip_open"
  c_gpiod_chip_open :: CString -> IO (Ptr CGpiodChip)
    
foreign import ccall "&gpiod_chip_close"
  p_gpiod_chip_close :: FunPtr (Ptr CGpiodChip -> IO ())

foreign import ccall "gpiod_chip_get_info"
  c_gpiod_chip_get_info :: Ptr CGpiodChip -> IO (Ptr CGpiodChipInfo) 

foreign import ccall "gpiod_chip_get_path"
  c_gpiod_chip_get_path :: Ptr CGpiodChip -> IO CString  

foreign import ccall "gpiod_chip_get_line_info"
  c_gpiod_chip_get_line_info :: Ptr CGpiodChip -> CUInt -> IO (Ptr CGpiodLineInfo) 

foreign import ccall "gpiod_chip_watch_line_info"
  c_gpiod_chip_watch_line_info :: Ptr CGpiodChip -> CUInt -> IO (Ptr CGpiodLineInfo) 
  
foreign import ccall "gpiod_chip_request_lines"
  c_gpiod_chip_request_lines :: Ptr CGpiodChip 
                             -> Ptr CGpiodRequestConfig
                             -> Ptr CGpiodLineConfig
                             -> IO (Ptr CGpiodLineRequest)

foreign import ccall "&gpiod_line_request_release"
  p_gpiod_line_request_release :: FunPtr (Ptr CGpiodLineRequest -> IO ())

-- --- Haskell API ---

-- | Helper to open and use a chip safely, guaranteeing its release.
withChip :: FilePath -> (Chip -> IO a) -> IO a
withChip path = bracket (openChip path) closeChip

-- | Open a GPIO chip by its filesystem path.
openChip :: FilePath -> IO Chip
openChip str = do
  chip <- throwErrnoPathIfNull "openChip" str $
            withCString str c_gpiod_chip_open
  Chip <$> newForeignPtr p_gpiod_chip_close chip

-- | Close a GPIO chip and release all associated resources.
closeChip :: Chip -> IO ()
closeChip (Chip chip) = finalizeForeignPtr chip

-- | Get information about the chip.
getChipInfo :: Chip -> IO ChipInfo
getChipInfo (Chip chip) = do
  res <- throwErrnoIfNull "getChipInfo" $ 
           withForeignPtr chip $ \ptr -> c_gpiod_chip_get_info ptr
  return $ ChipInfo res

-- | Get the path used to open the chip.
getChipPath :: Chip -> IO String
getChipPath (Chip chip) = do
  res <- throwErrnoIfNull "getChipPath" $
           withForeignPtr chip $ \ptr -> c_gpiod_chip_get_path ptr
  peekCString res
  
-- | Get a snapshot of information about a line. TO UNSAFE 
getChipLineInfo :: Chip -> LineOffset -> IO LineInfo
getChipLineInfo (Chip chip) (LineOffset offset) = do
  res <- throwErrnoIfNull "getChipPath" $
           withForeignPtr chip $ \ptr -> c_gpiod_chip_get_line_info ptr (fromIntegral offset)
  return $ LineInfo res 
        
-- | Request a set of lines from the chip.
requestLines :: Chip -> Maybe RequestConfig -> LineConfig -> IO LineRequest 
requestLines (Chip chip) maybeReqConf (LineConfig lineConf) = do
  let reqConfPtr = case maybeReqConf of
                     Just (RequestConfig ptr) -> ptr
                     Nothing                  -> nullPtr
  requestedLines <- throwErrnoIfNull "requestLines" $
    withForeignPtr chip $ \ptr -> c_gpiod_chip_request_lines ptr reqConfPtr lineConf
  LineRequest <$> newForeignPtr p_gpiod_line_request_release requestedLines 

--------------------------------------------------------------------------------
-- 3. CHIP INFO
--------------------------------------------------------------------------------

-- --- ADTs & Types ---

-- --- C FFI Imports ---
foreign import ccall "gpiod_chip_info_free"
  c_gpiod_chip_info_free ::  Ptr CGpiodChipInfo -> IO()
  
foreign import ccall "gpiod_chip_info_get_name"
  c_gpiod_chip_info_get_name ::  Ptr CGpiodChipInfo -> IO CString
  
foreign import ccall "gpiod_chip_info_get_label"
  c_gpiod_chip_info_get_label ::  Ptr CGpiodChipInfo -> IO CString  

foreign import ccall "gpiod_chip_info_get_num_lines"
  c_gpiod_chip_info_get_num_lines ::  Ptr CGpiodChipInfo -> IO CSize 

-- --- Haskell API ---

-- | Free a chip info object and release all associated resources.
chipInfoFree :: ChipInfo -> IO()
chipInfoFree (ChipInfo chipInfo) = c_gpiod_chip_info_free chipInfo 

-- | Get the name of the chip as represented in the kernel. 
getChipName :: ChipInfo -> IO String
getChipName (ChipInfo chipInfo) = do
  res <-  c_gpiod_chip_info_get_name chipInfo
  peekCString res 
  
-- | Get the label of the chip as represented in the kernel. 
getChipLabel :: ChipInfo -> IO String
getChipLabel (ChipInfo chipInfo) = do
  res <-  c_gpiod_chip_info_get_name chipInfo
  peekCString res 

-- | Get the number of lines exposed by the chip. 
getChipNumLines :: ChipInfo -> IO Int 
getChipNumLines (ChipInfo chipInfo) = do
  res <-  c_gpiod_chip_info_get_num_lines chipInfo
  return $ fromIntegral res

-- | MEJORAR COMENTARIO: EXPONER EN GPIO 
withChipInfo :: Chip -> (ChipInfo -> IO a) -> IO a
withChipInfo chip = bracket (getChipInfo chip) chipInfoFree

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION 
--------------------------------------------------------------------------------

-- --- Translators to C Values ---
foreign import ccall "gpiod_line_info_free"
  c_gpiod_line_info_free :: Ptr CGpiodLineInfo -> IO()

foreign import ccall "gpiod_line_info_copy"
  c_gpiod_line_info_copy :: Ptr CGpiodLineInfo -> IO (Ptr CGpiodLineInfo)
  
-- --- Haskell API ---
-- Free a line info object and release all associated resources. 
lineInfoFree :: LineInfo -> IO()
lineInfoFree (LineInfo lineInfo) = c_gpiod_line_info_free lineInfo

-- Copy a line info object. UNSAFE 


--------------------------------------------------------------------------------
-- 5. LINE SETTINGS
--------------------------------------------------------------------------------

-- --- ADTs & Enums ---

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

-- --- Translators to C Values ---

directionToC :: Direction -> CInt
directionToC DirAsIs   = 1
directionToC DirInput  = 2
directionToC DirOutput = 3

biasToC :: Bias -> CInt
biasToC BiasAsIs     = 1 
biasToC BiasUnknown  = 2
biasToC BiasDisabled = 3
biasToC BiasPullUp   = 4
biasToC BiasPullDown = 5 

edgeToC :: Edge -> CInt
edgeToC EdgeNone    = 1 
edgeToC EdgeRising  = 2
edgeToC EdgeFalling = 3 
edgeToC EdgeBoth    = 4 

-- --- C FFI Imports ---

foreign import ccall "gpiod_line_settings_new"
  c_gpiod_line_settings_new ::  IO (Ptr CGpiodLineSettings)

foreign import ccall "gpiod_line_settings_free"
  c_gpiod_line_settings_free :: Ptr CGpiodLineSettings -> IO ()
    
foreign import ccall "gpiod_line_settings_set_direction"
  c_gpiod_line_settings_set_direction :: Ptr CGpiodLineSettings -> CInt -> IO CInt

foreign import ccall "gpiod_line_settings_get_bias"
  c_gpiod_line_settings_get_bias :: Ptr CGpiodLineSettings -> IO CInt

foreign import ccall "gpiod_line_settings_set_bias"
  c_gpiod_line_settings_set_bias :: Ptr CGpiodLineSettings -> CInt -> IO CInt

foreign import ccall "gpiod_line_settings_set_edge_detection"
  c_gpiod_line_settings_set_edge_detection :: Ptr CGpiodLineSettings -> CInt -> IO CInt 

-- --- Haskell API ---

-- | Set the line direction in the settings.
setDirection :: LineSettings -> Direction -> IO ()
setDirection (LineSettings settings) dir =
  throwErrnoIfMinus1_ "setDirection" $
    c_gpiod_line_settings_set_direction settings (directionToC dir)

-- | Set the electrical bias (pull-up, pull-down, disabled) in the settings.
setBias :: LineSettings -> Bias -> IO ()
setBias _ BiasUnknown = ioError (userError "setBias: Cannot set an invalid bias value (BiasUnknown is only for query/return)")
setBias (LineSettings settings) bias =
  throwErrnoIfMinus1_ "setBias" $
    c_gpiod_line_settings_set_bias settings (biasToC bias)

-- | Set the edge detection (rising, falling, both) in the settings.
setEdgeDetection :: LineSettings -> Edge -> IO ()
setEdgeDetection (LineSettings settings) edge =
  throwErrnoIfMinus1_ "setEdgeDetection" $
    c_gpiod_line_settings_set_edge_detection settings (edgeToC edge)

-- | Allocate and use line settings safely, guaranteeing their release.
withLineSettings :: (LineSettings -> IO a) -> IO a
withLineSettings = bracket acquire release
  where acquire = do
          lineSettings <- throwErrnoIfNull "withLineSettings" c_gpiod_line_settings_new
          return $ LineSettings lineSettings   
        release (LineSettings lineSettings) = c_gpiod_line_settings_free lineSettings 

--------------------------------------------------------------------------------
-- 5. LINE CONFIGURATION
--------------------------------------------------------------------------------

-- --- C FFI Imports ---

foreign import ccall "gpiod_line_config_new"
  c_gpiod_line_config_new :: IO (Ptr CGpiodLineConfig)

foreign import ccall "gpiod_line_config_free"
  c_gpiod_line_config_free :: Ptr CGpiodLineConfig -> IO ()

foreign import ccall "gpiod_line_config_add_line_settings"
  c_gpiod_line_config_add_line_settings :: Ptr CGpiodLineConfig
                                        -> Ptr CUInt
                                        -> CSize
                                        -> Ptr CGpiodLineSettings 
                                        -> IO CInt

-- --- Haskell API ---

-- | Add specific settings to a group of offsets in the configuration.
addConfigToLineSettings :: LineConfig -> [LineOffset] -> LineSettings -> IO ()
addConfigToLineSettings (LineConfig config) pins (LineSettings settings) = do
  let size = fromIntegral (length pins)
  throwErrnoIfMinus1_ "addConfigToLineSettings" $
    withArray (map (\(LineOffset p) -> fromIntegral p) pins) $ \ptr -> 
      c_gpiod_line_config_add_line_settings config ptr size settings

-- | Allocate and use a line configuration safely, guaranteeing its release.
withLineConfig :: (LineConfig -> IO a) -> IO a
withLineConfig = bracket acquire release
  where acquire = do
          lineConfig <- throwErrnoIfNull "withLineConfig" c_gpiod_line_config_new
          return $ LineConfig lineConfig
        release (LineConfig lineConfig) = c_gpiod_line_config_free lineConfig 

--------------------------------------------------------------------------------
-- 6. LINE REQUESTS & I/O
--------------------------------------------------------------------------------

-- --- ADTs & Enums ---

data LineValue = LineActive | LineInactive | LineError  
  deriving (Eq, Ord, Show, Read, Bounded, Enum)

data TimeoutNs = Nanoseconds Word64 | Infinite 
  deriving (Eq, Ord, Show, Read)

data WaitResult 
  = Timeout
  | EventsReady ReadyRequest 
  deriving (Eq, Show)

-- --- Translators to C Values ---

lineValueToC :: LineValue -> CInt
lineValueToC LineActive   = 1
lineValueToC LineInactive = 0
lineValueToC LineError    = -1 

timeoutNsToC :: TimeoutNs -> CLong
timeoutNsToC Infinite         = -1
timeoutNsToC (Nanoseconds ns) = fromIntegral ns

-- --- C FFI Imports ---

foreign import ccall "gpiod_line_request_get_value"
  c_gpiod_line_request_get_value :: Ptr CGpiodLineRequest -> CUInt -> IO CInt 

foreign import ccall "gpiod_line_request_set_value"
  c_gpiod_line_request_set_value :: Ptr CGpiodLineRequest -> CUInt -> CInt -> IO CInt 

foreign import ccall "gpiod_line_request_wait_edge_events"
  c_gpiod_line_request_wait_edge_events  :: Ptr CGpiodLineRequest -> CLong -> IO CInt

foreign import ccall "gpiod_line_request_read_edge_events" 
  c_gpiod_line_request_read_edge_events :: Ptr CGpiodLineRequest -> Ptr CGpiodEdgeEventBuffer -> CSize -> IO CInt

-- --- Haskell API ---

-- | Get the logical value of a requested line.
getValue :: LineRequest -> LineOffset -> IO LineValue 
getValue (LineRequest request) (LineOffset offset) = do
  lineValue <- withForeignPtr request $
    \ptr  -> c_gpiod_line_request_get_value ptr (fromIntegral offset)
  case lineValue of 
    1 -> return LineActive 
    0 -> return LineInactive 
    _ -> return LineError  

-- | Set the logical value of a requested line.
setValue :: LineRequest -> LineOffset -> LineValue -> IO ()
setValue _ _ LineError =
  ioError (userError "setValue: Cannot use an invalid set line value (LineError)")
setValue (LineRequest request) (LineOffset offset) value =
  throwErrnoIfMinus1_ "setValue" $
    withForeignPtr request $ \ptr ->
      c_gpiod_line_request_set_value ptr (fromIntegral offset) (lineValueToC value)

-- | Close a request and release the requested lines.
closeLineRequest :: LineRequest -> IO ()
closeLineRequest (LineRequest request) = finalizeForeignPtr request

-- | Wait for edge events to occur on the requested lines.
waitEdgeEvents :: LineRequest -> TimeoutNs -> IO WaitResult 
waitEdgeEvents (LineRequest request) timeoutNs  = do
  res <- throwErrnoIfMinus1 "waitEdgeEvents" $
    withForeignPtr request $ \ptr ->
      c_gpiod_line_request_wait_edge_events ptr (timeoutNsToC timeoutNs)
  case res of
    1 -> return $ EventsReady (ReadyRequest request)  -- Hay un evento, puedes proceder a leer
    0 -> return Timeout  -- Timeout, no pasó nada
    _ -> ioError (userError "waitEdgeEvents: unexpected return value from gpiod_line_request_wait_edge_events")

-- | Allocate and use requested lines safely, guaranteeing their release.
withLineRequest :: Chip -> Maybe RequestConfig -> LineConfig -> (LineRequest -> IO a) -> IO a
withLineRequest chip reqConf lineConf =
  bracket (requestLines chip reqConf lineConf) closeLineRequest

--------------------------------------------------------------------------------
-- 7. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

-- --- ADTs & Types ---

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

-- --- Translators to C Values ---

edgeEventTypeToC :: EdgeEventType -> CInt
edgeEventTypeToC EventRising  = 1 
edgeEventTypeToC EventFalling = 2

cToEdgeEventType :: CInt -> EdgeEventType
cToEdgeEventType 1 = EventRising
cToEdgeEventType 2 = EventFalling
cToEdgeEventType _ = error "Invalid CInt to translate to Edge Event Type"

-- --- C FFI Imports ---

foreign import ccall "gpiod_edge_event_buffer_new"
  c_gpiod_edge_event_buffer_new :: CSize -> IO (Ptr CGpiodEdgeEventBuffer)
  
foreign import ccall "gpiod_edge_event_buffer_free"
  c_gpiod_edge_event_buffer_free :: Ptr CGpiodEdgeEventBuffer -> IO ()

foreign import ccall "gpiod_edge_event_get_event_type"
  c_gpiod_edge_event_get_event_type :: Ptr CGpiodEdgeEvent -> IO CInt

foreign import ccall "gpiod_edge_event_buffer_get_event"
  c_gpiod_edge_event_buffer_get_event :: Ptr CGpiodEdgeEventBuffer -> CULong -> IO (Ptr CGpiodEdgeEvent)

foreign import ccall "gpiod_edge_event_get_timestamp_ns" 
  c_gpiod_edge_event_get_timestamp_ns :: Ptr CGpiodEdgeEvent -> IO CULong 

foreign import ccall "gpiod_edge_event_get_line_offset"
  c_gpiod_edge_event_get_line_offset :: Ptr CGpiodEdgeEvent -> IO CUInt

-- --- Haskell API ---

-- | Convert a ReadyRequest to a LineRequest.
readyToLineRequest :: ReadyRequest -> LineRequest
readyToLineRequest (ReadyRequest fptr) = LineRequest fptr

-- | Read raw edge events into the buffer and return the number of events read.
readEventsIntoBuffer :: LineRequest -> EventBuffer -> IO Int
readEventsIntoBuffer (LineRequest fptr) (EventBuffer buffer (EventBufferCapacity maxEvents)) =
  withForeignPtr fptr $ \reqPtr -> do
    count <- throwErrnoIfMinus1 "readEventsIntoBuffer" $
      c_gpiod_line_request_read_edge_events reqPtr buffer (fromIntegral maxEvents)
    return (fromIntegral count)

-- | Retrieve a raw edge event pointer wrapper from the buffer at the specified index.
getRawEventFromBuffer :: EventBuffer -> BufferIndex -> IO RawEdgeEvent
getRawEventFromBuffer (EventBuffer buffer _) (BufferIndex idx) = do
  ptr <- throwErrnoIfNull "getRawEventFromBuffer" $
    c_gpiod_edge_event_buffer_get_event buffer (fromIntegral idx)
  return $ RawEdgeEvent ptr

-- | Extract the line offset from a raw edge event pointer.
getRawLineOffset :: RawEdgeEvent -> IO LineOffset
getRawLineOffset (RawEdgeEvent event) = do
  offset <- c_gpiod_edge_event_get_line_offset event
  return $ LineOffset (fromIntegral offset)

-- | Extract the event type from a raw edge event pointer.
getRawEventType :: RawEdgeEvent -> IO EdgeEventType
getRawEventType (RawEdgeEvent event) = do
  cType <- c_gpiod_edge_event_get_event_type event
  case cType of
    1 -> return EventRising 
    2 -> return EventFalling
    _ -> ioError (userError $ "getRawEventType: unexpected event type " ++ show cType)

-- | Extract the timestamp in nanoseconds from a raw edge event pointer.
getRawTimestampNs :: RawEdgeEvent -> IO TimestampNs
getRawTimestampNs (RawEdgeEvent event) = do
  ns <- c_gpiod_edge_event_get_timestamp_ns event
  return $ TimestampNs (fromIntegral ns)

-- | Parse a RawEdgeEvent pointer into a pure Haskell EdgeEvent structure.
rawToEdgeEvent :: RawEdgeEvent -> IO EdgeEvent
rawToEdgeEvent raw = EdgeEvent
  <$> getRawLineOffset raw
  <*> getRawEventType raw
  <*> getRawTimestampNs raw

-- | Read buffered edge events once waitEdgeEvents indicates they are ready.
readEdgeEvents :: ReadyRequest -> EventBuffer -> IO (NonEmpty EdgeEvent)
readEdgeEvents readyReq buf = do
  let req = readyToLineRequest readyReq
  count <- readEventsIntoBuffer req buf
  events <- forM [0 .. (count - 1)] $ \idx -> do
    raw <- getRawEventFromBuffer buf (BufferIndex (fromIntegral idx))
    rawToEdgeEvent raw
  case NE.nonEmpty events of
    Just ne -> return ne
    Nothing -> ioError (userError "readEdgeEvents: expected at least one event from ReadyRequest but got none")

-- | Process raw edge events directly in the buffer using a callback.
withRawEdgeEvents :: ReadyRequest -> EventBuffer -> (RawEdgeEvent -> IO a) -> IO (NonEmpty a)
withRawEdgeEvents readyReq buf action = do
  let req = readyToLineRequest readyReq
  count <- readEventsIntoBuffer req buf
  results <- forM [0 .. (count - 1)] $ \idx -> do
    raw <- getRawEventFromBuffer buf (BufferIndex (fromIntegral idx))
    action raw
  case NE.nonEmpty results of
    Just ne -> return ne
    Nothing -> ioError (userError "withRawEdgeEvents: expected at least one event from ReadyRequest but got none")

-- | Run a computation with a temporarily allocated event buffer, guaranteeing its release.
withEdgeEventBuffer :: EventBufferCapacity -> (EventBuffer -> IO a) -> IO a
withEdgeEventBuffer (EventBufferCapacity capacity) = bracket acquire release 
  where acquire = do
          res <- throwErrnoIfNull "withEdgeEventBuffer" $
            c_gpiod_edge_event_buffer_new (fromIntegral capacity)
          return $ EventBuffer res (EventBufferCapacity capacity)
        release (EventBuffer buffer _) = c_gpiod_edge_event_buffer_free buffer 
 
