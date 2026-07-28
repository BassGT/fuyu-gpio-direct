module Fuyu.GPIO.Direct
  ( module Fuyu.GPIO.Direct.Types
  , module Fuyu.GPIO.Direct.Bindings
  , module Fuyu.GPIO.Direct
  ) where

import System.Posix.Types (Fd(..))
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Foreign.C.Error (Errno, getErrno, eINVAL)
import Foreign.C.Types (CInt(..), CLong(..))
import Foreign.Marshal.Utils (toBool)
import Foreign.Ptr (Ptr, nullPtr)
import Data.Vector.Storable (Vector)
import qualified Data.Vector.Storable as V
import qualified Data.Vector.Storable.Mutable as MV
import Data.Word (Word64)

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
chipOpen :: ByteString -> IO (Either Errno Chip)
chipOpen bs = BS.useAsCString bs $ \cStr -> do
  res <- checkNull (c_gpiod_chip_open cStr)
  return $ Chip <$> res

-- | Close a GPIO chip and release all associated resources.
chipClose :: Chip -> IO ()
chipClose (Chip ptr) = c_gpiod_chip_close ptr

-- | Get information about the chip.
chipInfo :: Chip -> IO (Either Errno ChipInfo)
chipInfo (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_info ptr)
  return $ ChipInfo <$> res

-- | Get the path used to open the chip as ByteString.
chipPath :: Chip -> IO (Either Errno ByteString)
chipPath (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_path ptr)
  case res of
    Left err -> return (Left err)
    Right cStr -> Right <$> BS.packCString cStr

-- | Get a snapshot of information about a line.
chipLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
chipLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_get_line_info ptr offset
  return $ LineInfo <$> res

-- | Get a snapshot of the status of a line (LineOffset type) and start watching it for future changes.
chipWatchLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
chipWatchLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_watch_line_info ptr offset
  return $ LineInfo <$> res   

-- | Stop watching a line for status changes.
chipUnwatchLineInfo :: Chip -> LineOffset -> IO (Either Errno ())
chipUnwatchLineInfo (Chip ptr) offset = do
  checkMinusOne $ c_gpiod_chip_unwatch_line_info ptr offset

-- | Get the file descriptor associated with the chip.
chipFd :: Chip -> IO Fd
chipFd (Chip ptr) = c_gpiod_chip_get_fd ptr

-- | Wait for line status change events on any of the watched lines on the chip. 
chipWaitInfoEvent :: Chip -> TimeoutNs -> IO (Either Errno WaitResult)
chipWaitInfoEvent (Chip ptr) ns = do
  res <- c_gpiod_chip_wait_info_event ptr (fromIntegral $ timeoutNsToC ns)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout
  
-- | Read a single line status change event from the chip.
chipReadInfoEvent :: Chip -> IO (Either Errno InfoEvent)
chipReadInfoEvent (Chip ptr) = do
  res <- checkNull $ c_gpiod_chip_read_info_event ptr 
  return $ InfoEvent <$> res   

-- | Map a line’s name to its offset (LineOffset type) within the chip.
chipLineOffsetFromName :: Chip -> ByteString -> IO (Either Errno LineOffset)
chipLineOffsetFromName (Chip ptr) name = do
  res <- BS.useAsCString name $ \cStr -> c_gpiod_chip_get_line_offset_from_name ptr cStr
  if res == -1 
    then Left <$> getErrno 
    else return $ Right $ LineOffset (fromIntegral res)

-- | Request a set of lines from the chip.
chipRequestLines :: Chip -> Maybe RequestConfig -> LineConfig -> IO (Either Errno LineRequest)
chipRequestLines (Chip chipPtr) maybeReqConf (LineConfig lineConfPtr) = do
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
chipInfoFree (ChipInfo info) = c_gpiod_chip_info_free info 

-- | Get the name of the chip as represented in the kernel as ByteString. 
chipInfoName :: ChipInfo -> IO ByteString
chipInfoName (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_name info
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Get the label of the chip as represented in the kernel as ByteString. 
chipInfoLabel :: ChipInfo -> IO ByteString
chipInfoLabel (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_label info
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Get the number of lines exposed by the chip. 
chipInfoNumLines :: ChipInfo -> IO Word 
chipInfoNumLines (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_num_lines info
  return $ fromIntegral res

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

-- | Free a line info object.
lineInfoFree :: LineInfo -> IO ()
lineInfoFree (LineInfo info) = c_gpiod_line_info_free info

-- | Copy a line info object.
lineInfoCopy :: LineInfo -> IO (Either Errno LineInfo)
lineInfoCopy (LineInfo info) = do
  res <- checkNull (c_gpiod_line_info_copy info)
  return $ LineInfo <$> res

-- | Get the offset of the line. 
lineInfoOffset :: LineInfo -> IO LineOffset
lineInfoOffset (LineInfo info) = c_gpiod_line_info_get_offset info

-- | Get the name of the line as ByteString. 
lineInfoName :: LineInfo -> IO (Maybe ByteString)
lineInfoName (LineInfo info) = do
  res <- c_gpiod_line_info_get_name info
  if res == nullPtr
    then return Nothing
    else Just <$> BS.packCString res 

-- | Check if the line is in use. 
lineInfoIsUsed :: LineInfo -> IO Bool
lineInfoIsUsed (LineInfo info) = do
  res <- c_gpiod_line_info_is_used info
  return $ toBool res

-- | Get the GPIO consumer's name of the line as ByteString. 
lineInfoConsumer :: LineInfo -> IO (Maybe ByteString)
lineInfoConsumer (LineInfo info) = do
  name <- c_gpiod_line_info_get_consumer info
  if name == nullPtr
    then return Nothing
    else Just <$> BS.packCString name

-- | Get the direction setting of the line.
lineInfoDirection :: LineInfo -> IO LineDirection
lineInfoDirection (LineInfo info) = c_gpiod_line_info_get_direction info

-- | Get the edge detection setting of the line.
lineInfoEdgeDetection :: LineInfo -> IO LineEdge
lineInfoEdgeDetection (LineInfo info) = c_gpiod_line_info_get_edge_detection info

-- | Get the bias setting of the line.
lineInfoBias :: LineInfo -> IO LineBias
lineInfoBias (LineInfo info) = c_gpiod_line_info_get_bias info

-- | Get the drive setting of the line.
lineInfoDrive :: LineInfo -> IO LineDrive
lineInfoDrive (LineInfo info) = c_gpiod_line_info_get_drive info

-- | Check if the logical value of the line is inverted compared to physical.
lineInfoIsActiveLow :: LineInfo -> IO Bool
lineInfoIsActiveLow (LineInfo info) = do
  res <- c_gpiod_line_info_is_active_low info
  return $ toBool res

-- | Check if the line is debounced.
lineInfoIsDebounced :: LineInfo -> IO Bool
lineInfoIsDebounced (LineInfo info) = do
  res <- c_gpiod_line_info_is_debounced info
  return $ toBool res

-- | Get the debounce period of the line, in microseconds.
lineInfoDebouncePeriod :: LineInfo -> IO Word  
lineInfoDebouncePeriod (LineInfo info) = do
  res <- c_gpiod_line_info_get_debounce_period_us info
  return $ fromIntegral res

-- | Get the event clock of the line.
lineInfoEventClock :: LineInfo -> IO LineClock
lineInfoEventClock (LineInfo info) = c_gpiod_line_info_get_event_clock info

--------------------------------------------------------------------------------
-- 5. LINE WATCH (INFO EVENT) 
--------------------------------------------------------------------------------
-- | Free the info event object and release all associated resources. 
infoEventFree :: InfoEvent -> IO ()
infoEventFree (InfoEvent event) = c_gpiod_info_event_free event 

-- | Get the event type of the status change event.
infoEventType :: InfoEvent -> IO InfoEventType
infoEventType (InfoEvent event) = c_gpiod_info_event_get_event_type event 

-- | Get the timestamp in nanoseconds of the event. 
infoEventTimestamp :: InfoEvent -> IO TimestampNs 
infoEventTimestamp (InfoEvent event) = c_gpiod_info_event_get_timestamp_ns event

-- | Get the snapshot of line-info associated with the event.
infoEventLineInfo :: InfoEvent -> IO LineInfo
infoEventLineInfo (InfoEvent event) = LineInfo <$> c_gpiod_info_event_get_line_info event
  
--------------------------------------------------------------------------------
-- 6. LINE SETTINGS
--------------------------------------------------------------------------------
-- | Create a new line settings object.
lineSettingsNew :: IO (Either Errno LineSettings)
lineSettingsNew = do 
  res <- checkNull c_gpiod_line_settings_new
  return $ LineSettings <$> res 

-- | Free the line settings object and release all associated resources. 
lineSettingsFree :: LineSettings -> IO ()
lineSettingsFree (LineSettings settings) = c_gpiod_line_settings_free settings 

-- | Reset the line settings object to its default values. 
lineSettingsReset :: LineSettings -> IO ()
lineSettingsReset (LineSettings settings) = c_gpiod_line_settings_reset settings 

-- | Copy the line settings object.
lineSettingsCopy :: LineSettings -> IO (Either Errno LineSettings)
lineSettingsCopy (LineSettings settings) = do
  res <- checkNull (c_gpiod_line_settings_copy settings)
  return $ LineSettings <$> res

-- | Set the line direction in the settings.
lineSettingsSetDirection :: LineSettings -> LineDirection -> IO (Either Errno ())
lineSettingsSetDirection (LineSettings settings) dir =
  checkMinusOne $ c_gpiod_line_settings_set_direction settings dir
  
-- | Get the line direction in the settings.
lineSettingsDirection :: LineSettings -> IO LineDirection
lineSettingsDirection (LineSettings settings) = c_gpiod_line_settings_get_direction settings

-- | Set the edge detection in the settings.
lineSettingsSetEdgeDetection :: LineSettings -> LineEdge -> IO (Either Errno ())
lineSettingsSetEdgeDetection (LineSettings settings) edge =
  checkMinusOne $ c_gpiod_line_settings_set_edge_detection settings edge

-- | Get the edge detection in the settings.
lineSettingsEdgeDetection :: LineSettings -> IO LineEdge
lineSettingsEdgeDetection (LineSettings settings) = c_gpiod_line_settings_get_edge_detection settings

-- | Set the electrical bias in the settings.
lineSettingsSetBias :: LineSettings -> LineBias -> IO (Either Errno ())
lineSettingsSetBias (LineSettings settings) bias =
  checkMinusOne $ c_gpiod_line_settings_set_bias settings bias

-- | Get the electrical bias in the settings.
lineSettingsBias :: LineSettings -> IO LineBias
lineSettingsBias (LineSettings settings) = c_gpiod_line_settings_get_bias settings

-- | Set a drive setting in the settings.
lineSettingsSetDrive :: LineSettings -> LineDrive -> IO (Either Errno ())
lineSettingsSetDrive (LineSettings settings) drive =
  checkMinusOne $ c_gpiod_line_settings_set_drive settings drive

-- | Get the drive in the settings.
lineSettingsDrive :: LineSettings -> IO LineDrive
lineSettingsDrive (LineSettings settings) = c_gpiod_line_settings_get_drive settings

-- | Set event clock in the settings.
lineSettingsSetEventClock :: LineSettings -> LineClock -> IO (Either Errno ())
lineSettingsSetEventClock (LineSettings settings) clock =
  checkMinusOne $ c_gpiod_line_settings_set_event_clock settings clock

-- | Get event clock in the settings.
lineSettingsEventClock :: LineSettings -> IO LineClock
lineSettingsEventClock (LineSettings settings) = c_gpiod_line_settings_get_event_clock settings

-- | Set active-low setting.
lineSettingsSetActiveLow :: LineSettings -> Bool -> IO ()
lineSettingsSetActiveLow (LineSettings settings) activeLow =
  c_gpiod_line_settings_set_active_low settings (if activeLow then 1 else 0)

-- | Get active-low setting. 
lineSettingsActiveLow :: LineSettings -> IO Bool
lineSettingsActiveLow (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_active_low settings
  return $ toBool res

-- | Set debounce period in microseconds.
lineSettingsSetDebouncePeriodUs :: LineSettings -> Word -> IO ()
lineSettingsSetDebouncePeriodUs (LineSettings settings) us =
  c_gpiod_line_settings_set_debounce_period_us settings (fromIntegral us)

-- | Get debounce period in microseconds.
lineSettingsDebouncePeriodUs :: LineSettings -> IO Word
lineSettingsDebouncePeriodUs (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_debounce_period_us settings
  return $ fromIntegral res

-- | Set output value in the settings.
lineSettingsSetOutputValue :: LineSettings -> LineValue -> IO (Either Errno ())
lineSettingsSetOutputValue (LineSettings settings) val =
  checkMinusOne $ c_gpiod_line_settings_set_output_value settings val

-- | Get output value in the settings.
lineSettingsOutputValue :: LineSettings -> IO LineValue
lineSettingsOutputValue (LineSettings settings) = c_gpiod_line_settings_get_output_value settings

--------------------------------------------------------------------------------
-- 7. LINE CONFIGURATION
--------------------------------------------------------------------------------
-- | Create a new line config object.
lineConfigNew :: IO (Either Errno LineConfig)
lineConfigNew = do  
  res <- checkNull c_gpiod_line_config_new 
  return $ LineConfig <$> res

-- | Free the line config object and release all associated resources. 
lineConfigFree :: LineConfig -> IO ()
lineConfigFree (LineConfig config) = c_gpiod_line_config_free config

-- | Resets the entire configuration stored in the (config) object. This is useful if the user wants to reuse the object without reallocating it. 
lineConfigReset :: LineConfig -> IO ()
lineConfigReset (LineConfig config) = c_gpiod_line_config_reset config

-- | Add specific settings to a vector of line offsets in the configuration.
lineConfigAddLineSettings :: LineConfig -> Vector LineOffset -> LineSettings -> IO (Either Errno ())
lineConfigAddLineSettings (LineConfig config) offsets (LineSettings settings) = do
  let size = fromIntegral (V.length offsets)
  checkMinusOne $ V.unsafeWith offsets $ \ptr -> 
    c_gpiod_line_config_add_line_settings config ptr size settings

-- | Get line settings for offset.
lineConfigLineSettings :: LineConfig -> LineOffset -> IO (Either Errno LineSettings)
lineConfigLineSettings (LineConfig config) offset = do
  res <- checkNull $ c_gpiod_line_config_get_line_settings config offset
  return $ LineSettings <$> res 

-- | Set output values for a vector of lines. 
lineConfigSetOutputValues :: LineConfig -> Vector LineValue -> IO (Either Errno ())
lineConfigSetOutputValues (LineConfig config) values = do
  let size = fromIntegral (V.length values)
  checkMinusOne $ V.unsafeWith values $ \ptr ->
    c_gpiod_line_config_set_output_values config ptr size

-- | Get the number of configured line offsets.
lineConfigNumOffsets :: LineConfig -> IO Word  
lineConfigNumOffsets (LineConfig config) =
  fromIntegral <$> c_gpiod_line_config_get_num_configured_offsets config 

-- | Get all configured line offsets in the 'LineConfig' as a Storable 'Vector'.
lineConfigConfiguredOffsets :: LineConfig -> IO (Vector LineOffset)
lineConfigConfiguredOffsets (LineConfig config) = do
  num <- c_gpiod_line_config_get_num_configured_offsets config
  vec <- MV.new (fromIntegral num)
  _ <- MV.unsafeWith vec $ \ptr ->
    c_gpiod_line_config_get_configured_offsets config ptr num
  V.unsafeFreeze vec

--------------------------------------------------------------------------------
-- 8. REQUESTS CONFIG
--------------------------------------------------------------------------------
-- | Create a new request config object. 
requestConfigNew :: IO (Either Errno RequestConfig)
requestConfigNew = do  
  res <- checkNull c_gpiod_request_config_new  
  return $ RequestConfig <$> res 

-- | Create a new request config object. 
requestConfigFree :: RequestConfig -> IO()
requestConfigFree (RequestConfig config) = c_gpiod_request_config_free config

-- | Set the consumer name for the request.
requestConfigSetConsumer :: RequestConfig -> ByteString -> IO()
requestConfigSetConsumer (RequestConfig config) name =
  BS.useAsCString name $ \cStr -> do 
    c_gpiod_request_config_set_consumer config cStr
  
-- | Get the consumer name of the request config.
requestConfigConsumer :: RequestConfig -> IO ByteString
requestConfigConsumer (RequestConfig config) = do
  res <- c_gpiod_request_config_get_consumer config
  BS.packCString res 
    
-- | Set the size of the kernel event buffer for the request.
requestConfigSetEventBufferSize :: RequestConfig -> Word -> IO ()
requestConfigSetEventBufferSize (RequestConfig config) size =
  c_gpiod_request_config_set_event_buffer_size config (fromIntegral size)

-- | Get the size of the kernel event buffer for the request.
requestConfigEventBufferSize :: RequestConfig -> IO Word
requestConfigEventBufferSize (RequestConfig config) =
  fromIntegral <$> c_gpiod_request_config_get_event_buffer_size config

--------------------------------------------------------------------------------
-- 9. LINE REQUEST
--------------------------------------------------------------------------------
-- | Close a request and release requested lines.
lineRequestRelease :: LineRequest -> IO ()
lineRequestRelease (LineRequest request) = c_gpiod_line_request_release request

-- | Get the name of the chip this request was made on.
lineRequestChipName :: LineRequest -> IO ByteString
lineRequestChipName (LineRequest request) = do
  res <- c_gpiod_line_request_get_chip_name request
  BS.packCString res  
  
-- | Get the number of lines in the request.
lineRequestNumLines :: LineRequest -> IO Word 
lineRequestNumLines (LineRequest request) = 
  fromIntegral <$> c_gpiod_line_request_get_num_requested_lines request 

-- | Get all requested line offsets in the 'LineRequest' as a Storable 'Vector'.
lineRequestRequestedOffsets :: LineRequest -> IO (Vector LineOffset)
lineRequestRequestedOffsets (LineRequest request) = do
  num <- c_gpiod_line_request_get_num_requested_lines request
  vec <- MV.new (fromIntegral num)
  _ <- MV.unsafeWith vec $ \ptr ->
    c_gpiod_line_request_get_requested_offsets request ptr num
  V.unsafeFreeze vec

-- | Get the logical value of a requested line.
lineRequestValue :: LineRequest -> LineOffset -> IO (Either Errno LineValue)
lineRequestValue (LineRequest request) offset = do
  lineValue <- c_gpiod_line_request_get_value request offset
  if lineValue == LineError
    then Left <$> getErrno
    else return $ Right lineValue

-- | Get the values of a subset of requested lines into a Storable 'Vector'.
lineRequestSubsetValues :: LineRequest -> Vector LineOffset -> IO (Either Errno (Vector LineValue))
lineRequestSubsetValues (LineRequest request) offsets = do
  let numValues = V.length offsets
  mutValues <- MV.new numValues
  res <- V.unsafeWith offsets $ \offsetsPtr ->
    MV.unsafeWith mutValues $ \valuesPtr ->
      c_gpiod_line_request_get_values_subset request (fromIntegral numValues) offsetsPtr valuesPtr
  if res == -1
    then Left <$> getErrno
    else Right <$> V.unsafeFreeze mutValues

-- | Get the values of all requested lines into a Storable 'Vector'.
lineRequestValues :: LineRequest -> IO (Either Errno (Vector LineValue))
lineRequestValues (LineRequest request) = do
  numLines <- c_gpiod_line_request_get_num_requested_lines request
  mutValues <- MV.new (fromIntegral numLines)
  res <- MV.unsafeWith mutValues $ \valuesPtr ->
    c_gpiod_line_request_get_values request valuesPtr
  if res == -1
    then Left <$> getErrno
    else Right <$> V.unsafeFreeze mutValues

-- | Set the logical value of a requested line.
lineRequestSetValue :: LineRequest -> LineOffset -> LineValue -> IO (Either Errno ())
lineRequestSetValue _ _ LineError = return (Left eINVAL)
lineRequestSetValue (LineRequest request) offset value =
  checkMinusOne $ c_gpiod_line_request_set_value request offset value

-- | Set the logical values of a subset of requested lines from Storable 'Vector's of offsets and values.
lineRequestSetValuesSubset :: LineRequest -> Vector LineOffset -> Vector LineValue -> IO (Either Errno ())
lineRequestSetValuesSubset (LineRequest request) offsets values
  | V.length offsets /= V.length values = return (Left eINVAL)
  | otherwise =
      let numValues = V.length offsets
      in V.unsafeWith offsets $ \offsetsPtr ->
           V.unsafeWith values $ \valuesPtr ->
             checkMinusOne $ c_gpiod_line_request_set_values_subset request (fromIntegral numValues) offsetsPtr valuesPtr

-- | Set the logical values of all requested lines from a Storable 'Vector'.
lineRequestSetValues :: LineRequest -> Vector LineValue -> IO (Either Errno ())
lineRequestSetValues (LineRequest request) values =
  V.unsafeWith values $ \valuesPtr ->
    checkMinusOne $ c_gpiod_line_request_set_values request valuesPtr

-- | Update the configuration of lines associated with a line request.
lineRequestReconfigure :: LineRequest -> LineConfig -> IO (Either Errno ())
lineRequestReconfigure (LineRequest request) (LineConfig config) =
  checkMinusOne $ c_gpiod_line_request_reconfigure_lines request config  

-- | Get the file descriptor associated with the line request.
lineRequestFd :: LineRequest -> IO Fd
lineRequestFd (LineRequest request) = c_gpiod_line_request_get_fd request

-- | Wait for edge events to occur on requested lines.
lineRequestWaitEdgeEvents :: LineRequest -> TimeoutNs -> IO (Either Errno WaitResult)
lineRequestWaitEdgeEvents (LineRequest request) timeoutNs = do
  res <- c_gpiod_line_request_wait_edge_events request (timeoutNsToC timeoutNs)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout

-- | Read up to 'maxEvents' edge events from a line request into an 'EventBuffer'.
lineRequestReadEdgeEvents :: LineRequest -> EventBuffer -> Word -> IO (Either Errno Int)
lineRequestReadEdgeEvents (LineRequest reqPtr) (EventBuffer bufPtr) maxEvents = do
  count <- c_gpiod_line_request_read_edge_events reqPtr bufPtr (fromIntegral maxEvents)
  if count == -1
    then Left <$> getErrno
    else return $ Right (fromIntegral count)
--------------------------------------------------------------------------------
-- 10. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------
-- | Free a RawEdgeEvent.
rawEdgeEventFree :: RawEdgeEvent -> IO ()
rawEdgeEventFree (RawEdgeEvent event) = c_gpiod_edge_event_free event

-- | Copy a 'RawEdgeEvent'.
rawEdgeEventCopy :: RawEdgeEvent -> IO (Either Errno RawEdgeEvent)
rawEdgeEventCopy (RawEdgeEvent event) = do
  res <- checkNull (c_gpiod_edge_event_copy event)
  return $ RawEdgeEvent <$> res

-- | Extract event type from raw edge event pointer.
rawEdgeEventType :: RawEdgeEvent -> IO EdgeEventType
rawEdgeEventType (RawEdgeEvent event) = c_gpiod_edge_event_get_event_type event

-- | Extract timestamp in nanoseconds from raw edge event pointer.
rawEdgeEventTimestampNs :: RawEdgeEvent -> IO TimestampNs
rawEdgeEventTimestampNs (RawEdgeEvent event) = c_gpiod_edge_event_get_timestamp_ns event

-- | Get the offset of the line which triggered the event.
rawEdgeEventLineOffset :: RawEdgeEvent -> IO LineOffset
rawEdgeEventLineOffset (RawEdgeEvent event) = c_gpiod_edge_event_get_line_offset event 

-- | Get the global sequence number of the event.
rawEdgeEventGlobalSeqNo :: RawEdgeEvent -> IO Word64 
rawEdgeEventGlobalSeqNo (RawEdgeEvent event) =
  fromIntegral <$> c_gpiod_edge_event_get_global_seqno event  

-- | Get the event sequence number specific to the line.
rawEdgeEventLineSeqNo :: RawEdgeEvent -> IO LineOffset
rawEdgeEventLineSeqNo (RawEdgeEvent event) = c_gpiod_edge_event_get_line_seqno event  

-- | Allocate a new 'EventBuffer' with the specified capacity.
eventBufferNew :: EventBufferCapacity -> IO (Either Errno EventBuffer)
eventBufferNew cap = do
  res <- checkNull $ c_gpiod_edge_event_buffer_new cap
  return $ EventBuffer <$> res

-- | Get the capacity of an 'EventBuffer'.
eventBufferCapacity :: EventBuffer -> IO Word
eventBufferCapacity (EventBuffer buffer) =
  fromIntegral <$> c_gpiod_edge_event_buffer_get_capacity buffer 

-- | Free an 'EventBuffer' and release all associated resources.
eventBufferFree :: EventBuffer -> IO ()
eventBufferFree (EventBuffer buffer) = c_gpiod_edge_event_buffer_free buffer 

-- | Retrieve raw edge event pointer from buffer by index.
eventBufferGetEvent :: EventBuffer -> BufferIndex -> IO (Either Errno RawEdgeEvent)
eventBufferGetEvent (EventBuffer buffer) idx = do
  res <- checkNull (c_gpiod_edge_event_buffer_get_event buffer idx)
  return $ RawEdgeEvent <$> res

-- | gpiod_edge_event_buffer_get_num_events
eventBufferNumEvents :: EventBuffer -> IO Word
eventBufferNumEvents (EventBuffer buffer) =
  fromIntegral <$> c_gpiod_edge_event_buffer_get_num_events buffer  

--------------------------------------------------------------------------------
-- 11. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------
-- Check if the file pointed to by path is a GPIO chip character devic
isGPIOChip :: ByteString -> IO Bool
isGPIOChip path = do
  BS.useAsCString path (fmap toBool . c_gpiod_is_gpiochip_device)

-- Get the API version of the library as a 'ByteString'.
gpiodAPIVersion :: IO ByteString
gpiodAPIVersion = do
  ver <- c_gpiod_api_version
  BS.packCString ver 
