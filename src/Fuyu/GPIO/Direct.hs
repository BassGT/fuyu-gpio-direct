module Fuyu.GPIO.Direct
  ( module Fuyu.GPIO.Direct.Types
  , module Fuyu.GPIO.Direct.Bindings

  -- * 2. CHIP MANAGEMENT
  , withChip
  , openChip
  , closeChip
  , getChipInfo
  , getChipPath
  , getChipLineInfo
  , requestLines

  -- * 3. CHIP INFO
  , chipInfoFree
  , getChipName
  , getChipLabel
  , getChipNumLines
  , withChipInfo

  -- * 4. LINE INFORMATION
  , lineInfoFree
  , copyLineInfo
  , getLineOffset
  , getLineName
  , isLineUsed
  , getLineConsumer
  , getLineDirection
  , getLineEdgeDetection
  , getLineBias
  , isLineActiveLow
  , isDebounced
  , getDebouncePeriod

  -- * 5. LINE SETTINGS
  , directionToC
  , biasToC
  , edgeToC
  , setDirection
  , setBias
  , setEdgeDetection
  , withLineSettings

  -- * 6. LINE CONFIGURATION
  , addConfigToLineSettings
  , withLineConfig

  -- * 7. LINE REQUESTS & I/O
  , lineValueToC
  , timeoutNsToC
  , getValue
  , setValue
  , closeLineRequest
  , waitEdgeEvents
  , withLineRequest

  -- * 8. EDGE EVENTS & EVENT BUFFER
  , edgeEventTypeToC
  , cToEdgeEventType
  , readyToLineRequest
  , readEventsIntoBuffer
  , getRawEventFromBuffer
  , getRawLineOffset
  , getRawEventType
  , getRawTimestampNs
  , rawToEdgeEvent
  , readEdgeEvents
  , withRawEdgeEvents
  , withEdgeEventBuffer
  ) where

import Control.Exception (bracket)
import Control.Monad (forM)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE
import Foreign.C.Error
  ( throwErrnoIfMinus1
  , throwErrnoIfMinus1_
  , throwErrnoIfNull
  , throwErrnoPathIfNull
  )
import Foreign.C.String (peekCString, withCString)
import Foreign.C.Types (CInt(..), CLong(..))
import Foreign.ForeignPtr (finalizeForeignPtr, newForeignPtr, withForeignPtr)
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (toBool)
import Foreign.Ptr (nullPtr)

import Fuyu.GPIO.Direct.Bindings
import Fuyu.GPIO.Direct.Types

--------------------------------------------------------------------------------
-- 2. CHIP MANAGEMENT
--------------------------------------------------------------------------------

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
getChipPath :: Chip -> IO FilePath
getChipPath (Chip chip) = do
  res <- throwErrnoIfNull "getChipPath" $
           withForeignPtr chip $ \ptr -> c_gpiod_chip_get_path ptr
  peekCString res

-- | Get a snapshot of information about a line.
getChipLineInfo :: Chip -> LineOffset -> IO LineInfo
getChipLineInfo (Chip chip) (LineOffset offset) = do
  res <- throwErrnoIfNull "getChipLineInfo" $
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

-- | Free a chip info object and release all associated resources.
chipInfoFree :: ChipInfo -> IO ()
chipInfoFree (ChipInfo chipInfo) = c_gpiod_chip_info_free chipInfo 

-- | Get the name of the chip as represented in the kernel. 
getChipName :: ChipInfo -> IO String
getChipName (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_name chipInfo
  peekCString res 

-- | Get the label of the chip as represented in the kernel. 
getChipLabel :: ChipInfo -> IO String 
getChipLabel (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_label chipInfo
  peekCString res 

-- | Get the number of lines exposed by the chip. 
getChipNumLines :: ChipInfo -> IO Int 
getChipNumLines (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_num_lines chipInfo
  return $ fromIntegral res

-- | Perform an action with ChipInfo and automatically free it.
withChipInfo :: Chip -> (ChipInfo -> IO a) -> IO a
withChipInfo chip = bracket (getChipInfo chip) chipInfoFree

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

-- | Free a line info object.
lineInfoFree :: LineInfo -> IO ()
lineInfoFree (LineInfo info) = c_gpiod_line_info_free info

-- | Copy a line info object.
copyLineInfo :: LineInfo -> IO LineInfo
copyLineInfo (LineInfo info) = LineInfo <$> c_gpiod_line_info_copy info 

-- | Get the offset of the line. 
getLineOffset :: LineInfo -> IO LineOffset
getLineOffset (LineInfo info) = LineOffset . fromIntegral <$> c_gpiod_line_info_get_offset info  

-- | Get the name of the line. 
getLineName :: LineInfo -> IO (Maybe String)
getLineName (LineInfo info) = do
  res <- c_gpiod_line_info_get_name info
  if res == nullPtr
  then return Nothing
  else Just <$> peekCString res 

-- | Check if the line is in use. 
isLineUsed :: LineInfo -> IO Bool
isLineUsed (LineInfo info) = do
  res <- c_gpiod_line_info_is_used info
  return $ toBool res

-- | Get the GPIO consumer's name of the line as it is represented in the kernel. 
getLineConsumer :: LineInfo -> IO String
getLineConsumer (LineInfo info) = do
  name <- c_gpiod_line_info_get_consumer info  
  peekCString name

-- | Get the direction setting of the line.
getLineDirection :: LineInfo -> IO Direction
getLineDirection (LineInfo info) = do
  dir <- c_gpiod_line_info_get_direction info
  case dir of
    1 -> return DirAsIs
    2 -> return DirInput
    3 -> return DirOutput
    _ -> ioError (userError $ "getLineDirection: Unexpected enum of line direction " ++ show dir)

-- | Get the edge detection setting of the line.
getLineEdgeDetection :: LineInfo -> IO Edge
getLineEdgeDetection (LineInfo info) = do
  edge <- c_gpiod_line_info_get_edge_detection info
  case edge of
    1 -> return EdgeNone
    2 -> return EdgeRising
    3 -> return EdgeFalling
    4 -> return EdgeBoth 
    _ -> ioError (userError $ "getLineEdgeDetection: Unexpected enum of edge detection " ++ show edge)

-- | Get the bias setting of the line.
getLineBias :: LineInfo -> IO Bias
getLineBias (LineInfo info) = do
  bias <- c_gpiod_line_info_get_bias info
  case bias of
    1 -> return BiasAsIs 
    2 -> return BiasUnknown   
    3 -> return BiasDisabled 
    4 -> return BiasPullUp  
    5 -> return BiasPullDown
    _ -> ioError (userError $ "getLineBias: Unexpected enum of bias " ++ show bias)

-- | Check if the logical value of the line is inverted compared to physical.
isLineActiveLow :: LineInfo -> IO Bool
isLineActiveLow (LineInfo info) = do
  res <- c_gpiod_line_info_is_active_low info
  return $ toBool res

-- | Check if the line is debounced.
isDebounced :: LineInfo -> IO Bool
isDebounced (LineInfo info) = do
  res <- c_gpiod_line_info_is_debounced info
  return $ toBool res

-- | Get the debounce period of the line, in microseconds.
getDebouncePeriod :: LineInfo -> IO Word  
getDebouncePeriod (LineInfo info) = do
  res <- c_gpiod_line_info_get_debounce_period_us info
  return $ fromIntegral res

--------------------------------------------------------------------------------
-- 5. LINE SETTINGS
--------------------------------------------------------------------------------

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

-- | Set the line direction in the settings.
setDirection :: LineSettings -> Direction -> IO ()
setDirection (LineSettings settings) dir =
  throwErrnoIfMinus1_ "setDirection" $
    c_gpiod_line_settings_set_direction settings (directionToC dir)

-- | Set the electrical bias in the settings.
setBias :: LineSettings -> Bias -> IO ()
setBias _ BiasUnknown = ioError (userError "setBias: Cannot set an invalid bias value (BiasUnknown is only for query/return)")
setBias (LineSettings settings) bias =
  throwErrnoIfMinus1_ "setBias" $
    c_gpiod_line_settings_set_bias settings (biasToC bias)

-- | Set the edge detection in the settings.
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
-- 6. LINE CONFIGURATION
--------------------------------------------------------------------------------

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
-- 7. LINE REQUESTS & I/O
--------------------------------------------------------------------------------

lineValueToC :: LineValue -> CInt
lineValueToC LineActive   = 1
lineValueToC LineInactive = 0
lineValueToC LineError    = -1 

timeoutNsToC :: TimeoutNs -> CLong
timeoutNsToC Infinite         = -1
timeoutNsToC (Nanoseconds ns) = fromIntegral ns

-- | Get the logical value of a requested line.
getValue :: LineRequest -> LineOffset -> IO LineValue 
getValue (LineRequest request) (LineOffset offset) = do
  lineValue <- withForeignPtr request $
    \ptr -> c_gpiod_line_request_get_value ptr (fromIntegral offset)
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

-- | Close a request and release requested lines.
closeLineRequest :: LineRequest -> IO ()
closeLineRequest (LineRequest request) = finalizeForeignPtr request

-- | Wait for edge events to occur on requested lines.
waitEdgeEvents :: LineRequest -> TimeoutNs -> IO WaitResult 
waitEdgeEvents (LineRequest request) timeoutNs = do
  res <- throwErrnoIfMinus1 "waitEdgeEvents" $
    withForeignPtr request $ \ptr ->
      c_gpiod_line_request_wait_edge_events ptr (timeoutNsToC timeoutNs)
  case res of
    1 -> return $ EventsReady (ReadyRequest request)
    0 -> return Timeout
    _ -> ioError (userError "waitEdgeEvents: unexpected return value")

-- | Allocate and use requested lines safely, guaranteeing their release.
withLineRequest :: Chip -> Maybe RequestConfig -> LineConfig -> (LineRequest -> IO a) -> IO a
withLineRequest chip reqConf lineConf =
  bracket (requestLines chip reqConf lineConf) closeLineRequest

--------------------------------------------------------------------------------
-- 8. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

edgeEventTypeToC :: EdgeEventType -> CInt
edgeEventTypeToC EventRising  = 1 
edgeEventTypeToC EventFalling = 2

cToEdgeEventType :: CInt -> EdgeEventType
cToEdgeEventType 1 = EventRising
cToEdgeEventType 2 = EventFalling
cToEdgeEventType _ = error "Invalid CInt to translate to Edge Event Type"

-- | Convert a ReadyRequest to a LineRequest.
readyToLineRequest :: ReadyRequest -> LineRequest
readyToLineRequest (ReadyRequest fptr) = LineRequest fptr

-- | Read raw edge events into buffer.
readEventsIntoBuffer :: LineRequest -> EventBuffer -> IO Int
readEventsIntoBuffer (LineRequest fptr) (EventBuffer buffer (EventBufferCapacity maxEvents)) =
  withForeignPtr fptr $ \reqPtr -> do
    count <- throwErrnoIfMinus1 "readEventsIntoBuffer" $
      c_gpiod_line_request_read_edge_events reqPtr buffer (fromIntegral maxEvents)
    return (fromIntegral count)

-- | Retrieve raw edge event pointer from buffer.
getRawEventFromBuffer :: EventBuffer -> BufferIndex -> IO RawEdgeEvent
getRawEventFromBuffer (EventBuffer buffer _) (BufferIndex idx) = do
  ptr <- throwErrnoIfNull "getRawEventFromBuffer" $
    c_gpiod_edge_event_buffer_get_event buffer (fromIntegral idx)
  return $ RawEdgeEvent ptr

-- | Extract line offset from raw edge event pointer.
getRawLineOffset :: RawEdgeEvent -> IO LineOffset
getRawLineOffset (RawEdgeEvent event) = do
  offset <- c_gpiod_edge_event_get_line_offset event
  return $ LineOffset (fromIntegral offset)

-- | Extract event type from raw edge event pointer.
getRawEventType :: RawEdgeEvent -> IO EdgeEventType
getRawEventType (RawEdgeEvent event) = do
  cType <- c_gpiod_edge_event_get_event_type event
  case cType of
    1 -> return EventRising
    2 -> return EventFalling
    _ -> ioError (userError $ "getRawEventType: unexpected event type " ++ show cType)

-- | Extract timestamp in nanoseconds from raw edge event pointer.
getRawTimestampNs :: RawEdgeEvent -> IO TimestampNs
getRawTimestampNs (RawEdgeEvent event) = do
  ns <- c_gpiod_edge_event_get_timestamp_ns event
  return $ TimestampNs (fromIntegral ns)

-- | Parse RawEdgeEvent into pure EdgeEvent.
rawToEdgeEvent :: RawEdgeEvent -> IO EdgeEvent
rawToEdgeEvent raw = EdgeEvent
  <$> getRawLineOffset raw
  <*> getRawEventType raw
  <*> getRawTimestampNs raw

-- | Read buffered edge events once waitEdgeEvents indicates readiness.
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

-- | Process raw edge events directly in buffer using callback.
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

-- | Run a computation with temporary event buffer, guaranteeing release.
withEdgeEventBuffer :: EventBufferCapacity -> (EventBuffer -> IO a) -> IO a
withEdgeEventBuffer (EventBufferCapacity capacity) = bracket acquire release 
  where acquire = do
          res <- throwErrnoIfNull "withEdgeEventBuffer" $
            c_gpiod_edge_event_buffer_new (fromIntegral capacity)
          return $ EventBuffer res (EventBufferCapacity capacity)
        release (EventBuffer buffer _) = c_gpiod_edge_event_buffer_free buffer
