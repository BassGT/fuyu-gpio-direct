module Fuyu.GPIO.Direct
  ( module Fuyu.GPIO.Direct.Types
  , module Fuyu.GPIO.Direct.Bindings
  , module Fuyu.GPIO.Direct
  ) where

import Control.Exception (bracket)
import System.Posix.Types (Fd(..))
import Control.Monad (forM)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE
import Foreign.C.Error (Errno, getErrno, eINVAL)
import Foreign.C.Types (CInt(..), CLong(..))
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (toBool)
import Foreign.Ptr (Ptr, nullPtr)

import Fuyu.GPIO.Direct.Bindings
import Fuyu.GPIO.Direct.Types

--------------------------------------------------------------------------------
-- INTERNAL ERROR HELPERS
--------------------------------------------------------------------------------

checkNull :: IO (Ptr a) -> IO (Either Errno (Ptr a))
checkNull action = do
  ptr <- action
  if ptr == nullPtr
    then Left <$> getErrno
    else return $ Right ptr

checkMinusOne :: IO CInt -> IO (Either Errno ())
checkMinusOne action = do
  res <- action
  if res == -1
    then Left <$> getErrno
    else return $ Right ()
    
--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------
 
timeoutNsToC :: TimeoutNs -> CLong
timeoutNsToC Immediate        = 0
timeoutNsToC Infinite         = -1
timeoutNsToC (Nanoseconds ns) = fromIntegral ns

--------------------------------------------------------------------------------
-- 1. CHIP MANAGEMENT
--------------------------------------------------------------------------------

-- | Open a GPIO chip by its filesystem path as ByteString.
openChip :: ByteString -> IO (Either Errno Chip)
openChip bs = BS.useAsCString bs $ \cStr -> do
  res <- checkNull (c_gpiod_chip_open cStr)
  return $ Chip <$> res

-- | Close a GPIO chip and release all associated resources.
closeChip :: Chip -> IO ()
closeChip (Chip ptr) = c_gpiod_chip_close ptr

-- | Get information about the chip.
getChipInfo :: Chip -> IO (Either Errno ChipInfo)
getChipInfo (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_info ptr)
  return $ ChipInfo <$> res

-- | Get the path used to open the chip as ByteString.
getChipPath :: Chip -> IO (Either Errno ByteString)
getChipPath (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_path ptr)
  case res of
    Left err -> return (Left err)
    Right cStr -> Right <$> BS.packCString cStr

-- | Get a snapshot of information about a line.
getChipLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
getChipLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_get_line_info ptr offset
  return $ LineInfo <$> res

-- | Get a snapshot of the status of a line (LineOffset type) and start watching it for future changes.
watchChipLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
watchChipLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_watch_line_info ptr offset
  return $ LineInfo <$> res   

-- | Stop watching a line for status changes.
unwatchChipLineInfo :: Chip -> LineOffset -> IO (Either Errno ())
unwatchChipLineInfo (Chip ptr) offset = do
  checkMinusOne $ c_gpiod_chip_unwatch_line_info ptr offset

-- | Get the file descriptor associated with the chip.
getChipFd :: Chip -> IO Fd
getChipFd (Chip ptr) = Fd <$> c_gpiod_chip_get_fd ptr

-- | Wait for line status change events on any of the watched lines on the chip. 
waitChipInfoEvent :: Chip -> TimeoutNs -> IO (Either Errno WaitResult)
waitChipInfoEvent (Chip ptr) ns = do
  res <- c_gpiod_chip_wait_info_event ptr (fromIntegral $ timeoutNsToC ns)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout
  
-- | Read a single line status change event from the chip.
readChipInfoEvent :: Chip -> IO (Either Errno InfoEvent)
readChipInfoEvent (Chip ptr) = do
  res <- checkNull $ c_gpiod_chip_read_info_event ptr 
  return $ InfoEvent <$> res   

-- | Map a line’s name to its offset (LineOffset type) within the chip.
getChipLineOffsetFromName :: Chip -> ByteString -> IO (Either Errno LineOffset)
getChipLineOffsetFromName (Chip ptr) name = do
  res <- BS.useAsCString name $ \cStr -> c_gpiod_chip_get_line_offset_from_name ptr cStr
  if res == -1 
    then Left <$> getErrno 
    else return $ Right $ LineOffset (fromIntegral res)

-- | Request a set of lines from the chip.
requestLines :: Chip -> Maybe RequestConfig -> LineConfig -> IO (Either Errno LineRequest)
requestLines (Chip chipPtr) maybeReqConf (LineConfig lineConfPtr) = do
  let reqConfPtr = case maybeReqConf of
                     Just (RequestConfig ptr) -> ptr
                     Nothing                  -> nullPtr
  res <- checkNull (c_gpiod_chip_request_lines chipPtr reqConfPtr lineConfPtr)
  return $ LineRequest <$> res

--------------------------------------------------------------------------------
-- 2. CHIP INFO
--------------------------------------------------------------------------------

-- | Free a chip info object and release all associated resources.
chipInfoFree :: ChipInfo -> IO ()
chipInfoFree (ChipInfo chipInfo) = c_gpiod_chip_info_free chipInfo 

-- | Get the name of the chip as represented in the kernel as ByteString. 
getChipName :: ChipInfo -> IO ByteString
getChipName (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_name chipInfo
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Get the label of the chip as represented in the kernel as ByteString. 
getChipLabel :: ChipInfo -> IO ByteString
getChipLabel (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_label chipInfo
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Get the number of lines exposed by the chip. 
getChipNumLines :: ChipInfo -> IO Word 
getChipNumLines (ChipInfo chipInfo) = do
  res <- c_gpiod_chip_info_get_num_lines chipInfo
  return $ fromIntegral res

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

-- | Free a line info object.
lineInfoFree :: LineInfo -> IO ()
lineInfoFree (LineInfo info) = c_gpiod_line_info_free info

-- | Copy a line info object.
copyLineInfo :: LineInfo -> IO (Either Errno LineInfo)
copyLineInfo (LineInfo info) = do
  res <- checkNull (c_gpiod_line_info_copy info)
  return $ LineInfo <$> res

-- | Get the offset of the line. 
getLineInfoOffset :: LineInfo -> IO LineOffset
getLineInfoOffset (LineInfo info) = c_gpiod_line_info_get_offset info

-- | Get the name of the line as ByteString. 
getLineInfoName :: LineInfo -> IO (Maybe ByteString)
getLineInfoName (LineInfo info) = do
  res <- c_gpiod_line_info_get_name info
  if res == nullPtr
    then return Nothing
    else Just <$> BS.packCString res 

-- | Check if the line is in use. 
isLineInfoUsed :: LineInfo -> IO Bool
isLineInfoUsed (LineInfo info) = do
  res <- c_gpiod_line_info_is_used info
  return $ toBool res

-- | Get the GPIO consumer's name of the line as ByteString. 
getLineInfoConsumer :: LineInfo -> IO (Maybe ByteString)
getLineInfoConsumer (LineInfo info) = do
  name <- c_gpiod_line_info_get_consumer info
  if name == nullPtr
    then return Nothing
    else Just <$> BS.packCString name

-- | Get the direction setting of the line.
getLineInfoDirection :: LineInfo -> IO LineDirection
getLineInfoDirection (LineInfo info) = c_gpiod_line_info_get_direction info

-- | Get the edge detection setting of the line.
getLineInfoEdgeDetection :: LineInfo -> IO LineEdge
getLineInfoEdgeDetection (LineInfo info) = c_gpiod_line_info_get_edge_detection info

-- | Get the bias setting of the line.
getLineInfoBias :: LineInfo -> IO LineBias
getLineInfoBias (LineInfo info) = c_gpiod_line_info_get_bias info

-- | Get the drive setting of the line.
getLineInfoDrive :: LineInfo -> IO LineDrive
getLineInfoDrive (LineInfo info) = c_gpiod_line_info_get_drive info

-- | Check if the logical value of the line is inverted compared to physical.
isLineInfoActiveLow :: LineInfo -> IO Bool
isLineInfoActiveLow (LineInfo info) = do
  res <- c_gpiod_line_info_is_active_low info
  return $ toBool res

-- | Check if the line is debounced.
isLineInfoDebounced :: LineInfo -> IO Bool
isLineInfoDebounced (LineInfo info) = do
  res <- c_gpiod_line_info_is_debounced info
  return $ toBool res

-- | Get the debounce period of the line, in microseconds.
getLineInfoDebouncePeriod :: LineInfo -> IO Word  
getLineInfoDebouncePeriod (LineInfo info) = do
  res <- c_gpiod_line_info_get_debounce_period_us info
  return $ fromIntegral res

-- | Get the event clock of the line.
getLineInfoEventClock :: LineInfo -> IO LineClock
getLineInfoEventClock (LineInfo info) = c_gpiod_line_info_get_event_clock info

--------------------------------------------------------------------------------
-- 5. LINE WATCH (INFO EVENT) 
--------------------------------------------------------------------------------
-- | Free the info event object and release all associated resources. 
infoEventFree :: InfoEvent -> IO ()
infoEventFree (InfoEvent event) = c_gpiod_info_event_free event 

-- | Get the event type of the status change event.
getInfoEventType :: InfoEvent -> IO InfoEventType
getInfoEventType (InfoEvent event) = c_gpiod_info_event_get_event_type event 

-- | Get the timestamp in nanoseconds of the event (readed from the monotonic clock). 
getInfoEventTimestamp :: InfoEvent -> IO TimestampNs 
getInfoEventTimestamp (InfoEvent event) = c_gpiod_info_event_get_timestamp_ns event

-- | Get the snapshot of line-info associated with the event.
getLineInfoOfInfoEvent :: InfoEvent -> IO LineInfo
getLineInfoOfInfoEvent (InfoEvent event) = LineInfo <$> c_gpiod_info_event_get_line_info event
  
--------------------------------------------------------------------------------
-- 6. LINE SETTINGS
--------------------------------------------------------------------------------
-- | Create a new line settings object.
newLineSettings :: IO (Either Errno LineSettings)
newLineSettings = do 
  res <- checkNull c_gpiod_line_settings_new
  return $ LineSettings <$> res 

-- | Free the line settings object and release all associated resources. 
freeLineSettings :: LineSettings -> IO ()
freeLineSettings (LineSettings settings) = c_gpiod_line_settings_free settings 

-- | Reset the line settings object to its default values. 
resetLineSettings :: LineSettings -> IO ()
resetLineSettings (LineSettings settings) = c_gpiod_line_settings_reset settings 

-- | Copy the line settings object.
copyLineSettings :: LineSettings -> IO (Either Errno LineSettings)
copyLineSettings (LineSettings settings) = do
  res <- checkNull (c_gpiod_line_settings_copy settings)
  return $ LineSettings <$> res

-- | Set the line direction in the settings.
setLineSettingsDirection :: LineSettings -> LineDirection -> IO (Either Errno ())
setLineSettingsDirection (LineSettings settings) dir =
  checkMinusOne $ c_gpiod_line_settings_set_direction settings dir
  
-- | Get the line direction in the settings.
getLineSettingsDirection :: LineSettings -> IO LineDirection
getLineSettingsDirection (LineSettings settings) = c_gpiod_line_settings_get_direction settings

-- | Set the edge detection in the settings.
setLineSettingsEdgeDetection :: LineSettings -> LineEdge -> IO (Either Errno ())
setLineSettingsEdgeDetection (LineSettings settings) edge =
  checkMinusOne $ c_gpiod_line_settings_set_edge_detection settings edge

-- | Get the edge detection in the settings.
getLineSettingsEdgeDetection :: LineSettings -> IO LineEdge
getLineSettingsEdgeDetection (LineSettings settings) = c_gpiod_line_settings_get_edge_detection settings

-- | Set the electrical bias in the settings.
setLineSettingsBias :: LineSettings -> LineBias -> IO (Either Errno ())
setLineSettingsBias (LineSettings settings) bias =
  checkMinusOne $ c_gpiod_line_settings_set_bias settings bias

-- | Get the electrical bias in the settings.
getLineSettingsBias :: LineSettings -> IO LineBias
getLineSettingsBias (LineSettings settings) = c_gpiod_line_settings_get_bias settings

-- | Set a drive setting in the settings.
setLineSettingsDrive :: LineSettings -> LineDrive -> IO (Either Errno ())
setLineSettingsDrive (LineSettings settings) drive =
  checkMinusOne $ c_gpiod_line_settings_set_drive settings drive

-- | Get the drive in the settings.
getLineSettingsDrive :: LineSettings -> IO LineDrive
getLineSettingsDrive (LineSettings settings) = c_gpiod_line_settings_get_drive settings

-- | Set event clock in the settings.
setLineSettingsEventClock :: LineSettings -> LineClock -> IO (Either Errno ())
setLineSettingsEventClock (LineSettings settings) clock =
  checkMinusOne $ c_gpiod_line_settings_set_event_clock settings clock

-- | Get event clock in the settings.
getLineSettingsEventClock :: LineSettings -> IO LineClock
getLineSettingsEventClock (LineSettings settings) = c_gpiod_line_settings_get_event_clock settings

-- | Set active-low setting.
setLineSettingsActiveLow :: LineSettings -> Bool -> IO ()
setLineSettingsActiveLow (LineSettings settings) activeLow =
  c_gpiod_line_settings_set_active_low settings (if activeLow then 1 else 0)

-- | Get active-low setting. 
getLineSettingsActiveLow :: LineSettings -> IO Bool
getLineSettingsActiveLow (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_active_low settings
  return $ toBool res

-- | Set debounce period in microseconds.
setLineSettingsDebouncePeriodUs :: LineSettings -> Word -> IO ()
setLineSettingsDebouncePeriodUs (LineSettings settings) us =
  c_gpiod_line_settings_set_debounce_period_us settings (fromIntegral us)

-- | Get debounce period in microseconds.
getLineSettingsDebouncePeriodUs :: LineSettings -> IO Word
getLineSettingsDebouncePeriodUs (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_debounce_period_us settings
  return $ fromIntegral res

-- | Set output value in the settings.
setLineSettingsOutputValue :: LineSettings -> LineValue -> IO (Either Errno ())
setLineSettingsOutputValue (LineSettings settings) val =
  checkMinusOne $ c_gpiod_line_settings_set_output_value settings val

-- | Get output value in the settings.
getLineSettingsOutputValue :: LineSettings -> IO LineValue
getLineSettingsOutputValue (LineSettings settings) = c_gpiod_line_settings_get_output_value settings

--------------------------------------------------------------------------------
-- 7. LINE CONFIGURATION
--------------------------------------------------------------------------------
-- | Create a new line config object.
newLineConfig :: IO (Either Errno LineConfig)
newLineConfig = do  
  res <- checkNull c_gpiod_line_config_new 
  return $ LineConfig <$> res

-- | Free the line config object and release all associated resources. 
freeLineConfig :: LineConfig -> IO ()
freeLineConfig (LineConfig config) = c_gpiod_line_config_free config

-- | Resets the entire configuration stored in the (config) object. This is useful if the user wants to reuse the object without reallocating it. 
resetLineConfig :: LineConfig -> IO ()
resetLineConfig (LineConfig config) = c_gpiod_line_config_reset config

-- | Add specific settings to a group of offsets in the configuration.
addConfigToLineSettings :: LineConfig -> [LineOffset] -> LineSettings -> IO (Either Errno ())
addConfigToLineSettings (LineConfig config) pins (LineSettings settings) = do
  let size = fromIntegral (length pins)
  checkMinusOne $ withArray pins $ \ptr -> 
    c_gpiod_line_config_add_line_settings config ptr size settings

-- | Get line settings for offset.
getLineConfigSettings :: LineConfig -> LineOffset -> IO (Either Errno LineSettings)
getLineConfigSettings (LineConfig config) offset = do
  res <- checkNull $ c_gpiod_line_config_get_line_settings config offset
  return $ LineSettings <$> res 

--------------------------------------------------------------------------------
-- 8. LINE REQUESTS & I/O
--------------------------------------------------------------------------------

-- | Get the logical value of a requested line.
getValue :: LineRequest -> LineOffset -> IO (Either Errno LineValue)
getValue (LineRequest requestPtr) offset = do
  lineValue <- c_gpiod_line_request_get_value requestPtr offset
  if lineValue == LineError
    then Left <$> getErrno
    else return $ Right lineValue

-- | Set the logical value of a requested line.
setValue :: LineRequest -> LineOffset -> LineValue -> IO (Either Errno ())
setValue _ _ LineError = return (Left eINVAL)
setValue (LineRequest requestPtr) offset value =
  checkMinusOne $ c_gpiod_line_request_set_value requestPtr offset value

-- | Close a request and release requested lines.
closeLineRequest :: LineRequest -> IO ()
closeLineRequest (LineRequest requestPtr) = c_gpiod_line_request_release requestPtr

-- | Wait for edge events to occur on requested lines.
waitEdgeEvents :: LineRequest -> TimeoutNs -> IO (Either Errno WaitResult)
waitEdgeEvents (LineRequest requestPtr) timeoutNs = do
  res <- c_gpiod_line_request_wait_edge_events requestPtr (timeoutNsToC timeoutNs)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout

--------------------------------------------------------------------------------
-- 8. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

-- | Read raw edge events into buffer.
readEventsIntoBuffer :: LineRequest -> EventBuffer -> IO (Either Errno Int)
readEventsIntoBuffer (LineRequest reqPtr) (EventBuffer buffer (EventBufferCapacity maxEvents)) = do
  count <- c_gpiod_line_request_read_edge_events reqPtr buffer maxEvents
  if count == -1
    then Left <$> getErrno
    else return $ Right (fromIntegral count)

-- | Retrieve raw edge event pointer from buffer.
getRawEventFromBuffer :: EventBuffer -> BufferIndex -> IO (Either Errno RawEdgeEvent)
getRawEventFromBuffer (EventBuffer buffer _) idx = do
  res <- checkNull (c_gpiod_edge_event_buffer_get_event buffer idx)
  return $ RawEdgeEvent <$> res

-- | Extract line offset from raw edge event pointer.
getRawLineOffset :: RawEdgeEvent -> IO LineOffset
getRawLineOffset (RawEdgeEvent event) = c_gpiod_edge_event_get_line_offset event

-- | Extract event type from raw edge event pointer.
getRawEventType :: RawEdgeEvent -> IO EdgeEventType
getRawEventType (RawEdgeEvent event) = c_gpiod_edge_event_get_event_type event

-- | Extract timestamp in nanoseconds from raw edge event pointer.
getRawTimestampNs :: RawEdgeEvent -> IO TimestampNs
getRawTimestampNs (RawEdgeEvent event) = c_gpiod_edge_event_get_timestamp_ns event

-- | Parse RawEdgeEvent into pure EdgeEvent.
rawToEdgeEvent :: RawEdgeEvent -> IO EdgeEvent
rawToEdgeEvent raw = EdgeEvent
  <$> getRawLineOffset raw
  <*> getRawEventType raw
  <*> getRawTimestampNs raw

-- | Read buffered edge events once waitEdgeEvents indicates readiness.
readEdgeEvents :: LineRequest -> EventBuffer -> IO (Either Errno (NonEmpty EdgeEvent))
readEdgeEvents req buf = do
  eCount <- readEventsIntoBuffer req buf
  case eCount of
    Left err -> return (Left err)
    Right count -> do
      events <- forM [0 .. (count - 1)] $ \idx -> do
        eRaw <- getRawEventFromBuffer buf (BufferIndex (fromIntegral idx))
        case eRaw of
          Left _ -> error "readEdgeEvents: invalid raw event index"
          Right raw -> rawToEdgeEvent raw
      case NE.nonEmpty events of
        Just ne -> return (Right ne)
        Nothing -> return (Left eINVAL)

