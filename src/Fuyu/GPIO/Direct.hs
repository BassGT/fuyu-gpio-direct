{-# LANGUAGE PatternSynonyms #-}
-- |
-- Module      : Fuyu.GPIO.Direct
-- Description : Mid-level Haskell bindings for Linux GPIO character device interface (libgpiod v2).
-- Maintainer  : BassGT
-- Portability : POSIX (Linux GPIO character device interface)
--
-- High-level direct Haskell interface for interacting with Linux GPIO character devices
-- using @libgpiod v2@.
module Fuyu.GPIO.Direct
  ( -- * Module Overview
    -- $overview

    -- * High-Level Opaque Handles (Abstract Types)
    Chip
  , ChipInfo
  , InfoEvent
  , LineInfo
  , LineSettings
  , LineConfig
  , LineRequest
  , RequestConfig
  , EventBuffer
  , RawEdgeEvent

    -- * Safety & Index Wrappers
  , LineOffset(..)

    -- * Line Definitions & Patterns
  , LineValue(..)
  , pattern LineActive
  , pattern LineInactive
  , pattern LineError

  , LineDirection(..)
  , pattern DirAsIs
  , pattern DirInput
  , pattern DirOutput

  , LineEdge(..)
  , pattern EdgeNone
  , pattern EdgeRising
  , pattern EdgeFalling
  , pattern EdgeBoth

  , LineBias(..)
  , pattern BiasAsIs
  , pattern BiasUnknown
  , pattern BiasDisabled
  , pattern BiasPullUp
  , pattern BiasPullDown

  , LineDrive(..)
  , pattern PushPull
  , pattern OpenDrain
  , pattern OpenSource

  , LineClock(..)
  , pattern Monotonic
  , pattern Realtime
  , pattern Hardware

  , InfoEventType(..)
  , pattern LineRequested
  , pattern LineReleased
  , pattern LineConfigChanged

  , EdgeEventType(..)
  , pattern Rising
  , pattern Falling

  , WaitResult(..)
  , TimeoutNs(..)
  , TimestampNs
  , EdgeEvent(..)

    -- * Chip Management
  , chipOpen
  , chipClose
  , chipInfo
  , chipPath
  , chipLineInfo
  , chipWatchLineInfo
  , chipUnwatchLineInfo
  , chipFd
  , chipWaitInfoEvent
  , chipReadInfoEvent
  , chipLineOffsetFromName
  , chipRequestLines

    -- * Chip Info
  , chipInfoFree
  , chipInfoName
  , chipInfoLabel
  , chipInfoNumLines

    -- * Line Information
  , lineInfoFree
  , lineInfoCopy
  , lineInfoOffset
  , lineInfoName
  , lineInfoIsUsed
  , lineInfoConsumer
  , lineInfoDirection
  , lineInfoEdgeDetection
  , lineInfoBias
  , lineInfoDrive
  , lineInfoIsActiveLow
  , lineInfoIsDebounced
  , lineInfoDebouncePeriod
  , lineInfoEventClock

    -- * Line Watch (Info Event)
  , infoEventFree
  , infoEventType
  , infoEventTimestamp
  , infoEventLineInfo

    -- * Line Settings
  , lineSettingsNew
  , lineSettingsFree
  , lineSettingsReset
  , lineSettingsCopy
  , lineSettingsSetDirection
  , lineSettingsDirection
  , lineSettingsSetEdgeDetection
  , lineSettingsEdgeDetection
  , lineSettingsSetBias
  , lineSettingsBias
  , lineSettingsSetDrive
  , lineSettingsDrive
  , lineSettingsSetEventClock
  , lineSettingsEventClock
  , lineSettingsSetActiveLow
  , lineSettingsActiveLow
  , lineSettingsSetDebouncePeriodUs
  , lineSettingsDebouncePeriodUs
  , lineSettingsSetOutputValue
  , lineSettingsOutputValue

    -- * Line Configuration
  , lineConfigNew
  , lineConfigFree
  , lineConfigReset
  , lineConfigAddLineSettings
  , lineConfigLineSettings
  , lineConfigSetOutputValues
  , lineConfigNumOffsets
  , lineConfigConfiguredOffsets

    -- * Request Configuration
  , requestConfigNew
  , requestConfigFree
  , requestConfigSetConsumer
  , requestConfigConsumer
  , requestConfigSetEventBufferSize
  , requestConfigEventBufferSize

    -- * Line Request
  , lineRequestRelease
  , lineRequestChipName
  , lineRequestNumLines
  , lineRequestRequestedOffsets
  , lineRequestValue
  , lineRequestSubsetValues
  , lineRequestValues
  , lineRequestSetValue
  , lineRequestSetValuesSubset
  , lineRequestSetValues
  , lineRequestReconfigure
  , lineRequestFd
  , lineRequestWaitEdgeEvents
  , lineRequestReadEdgeEvents

    -- * Edge Events & Event Buffer
  , rawEdgeEventFree
  , rawEdgeEventCopy
  , rawEdgeEventType
  , rawEdgeEventTimestampNs
  , rawEdgeEventLineOffset
  , rawEdgeEventGlobalSeqNo
  , rawEdgeEventLineSeqNo
  , eventBufferNew
  , eventBufferCapacity
  , eventBufferFree
  , eventBufferGetEvent
  , eventBufferNumEvents

    -- * Utilities
  , isGPIOChip
  , gpiodAPIVersion
  ) where

import System.Posix.Types (Fd)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Foreign.C.Error (Errno, getErrno, eINVAL)
import Foreign.C.Types (CInt, CLong)
import Foreign.Marshal.Utils (toBool)
import Foreign.Ptr (Ptr, nullPtr)
import Data.Vector.Storable (Vector)
import qualified Data.Vector.Storable as V
import qualified Data.Vector.Storable.Mutable as MV
import Data.Word (Word64)

import Fuyu.GPIO.Direct.Bindings
import Fuyu.GPIO.Direct.Types

-- $overview
-- High-level direct Haskell interface for interacting with Linux GPIO character devices
-- using @libgpiod v2@.
--
-- This module wraps lower-level FFI calls into type-safe Haskell operations using 'ByteString',
-- 'Vector', and 'Either' 'Foreign.C.Error.Errno' error handling.
--
-- All resources wrapping C pointers (such as t'Chip, t'LineInfo, t'LineSettings, t'LineConfig,
-- t'LineRequest, etc.) must be explicitly freed or released when no longer needed.

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

-- | Open a GPIO chip device node at the given filesystem path (e.g. @"/dev/gpiochip4"@).
--
-- Returns 'Right' t'Chip on success, or 'Left' 'Errno' on failure (such as 'Foreign.C.Error.eACCES'
-- if permissions are missing or 'Foreign.C.Error.eNOENT' if the path does not exist).
-- The returned handle must be closed with 'chipClose' when finished to free file descriptors and memory.
chipOpen :: ByteString -> IO (Either Errno Chip)
chipOpen bs = BS.useAsCString bs $ \cStr -> do
  res <- checkNull (c_gpiod_chip_open cStr)
  return $ Chip <$> res

-- | Close an open GPIO chip device handle and release associated kernel and C resources.
chipClose :: Chip -> IO ()
chipClose (Chip ptr) = c_gpiod_chip_close ptr

-- | Query static information (device name, label, line count) about an open GPIO chip.
--
-- Returns 'Right' t'ChipInfo on success. The caller must explicitly free the returned
-- object using 'chipInfoFree'.
chipInfo :: Chip -> IO (Either Errno ChipInfo)
chipInfo (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_info ptr)
  return $ ChipInfo <$> res

-- | Retrieve the filesystem device path used when opening the chip.
--
-- Returns 'Right' 'ByteString' containing the path (e.g. @"/dev/gpiochip0"@).
chipPath :: Chip -> IO (Either Errno ByteString)
chipPath (Chip ptr) = do
  res <- checkNull (c_gpiod_chip_get_path ptr)
  case res of
    Left err -> return (Left err)
    Right cStr -> Right <$> BS.packCString cStr

-- | Query a snapshot of status and configuration information for a specific line offset.
--
-- Returns 'Right' t'LineInfo on success. The caller must explicitly free the returned
-- object using 'lineInfoFree'.
chipLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
chipLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_get_line_info ptr offset
  return $ LineInfo <$> res

-- | Query line status snapshot and subscribe to status change events for the specified line offset.
--
-- Future status change events (such as line requested, released, or reconfigured) can be waited for
-- via 'chipWaitInfoEvent' and read via 'chipReadInfoEvent'.
-- The caller must explicitly free the returned t'LineInfo object using 'lineInfoFree'.
chipWatchLineInfo :: Chip -> LineOffset -> IO (Either Errno LineInfo)
chipWatchLineInfo (Chip ptr) offset = do
  res <- checkNull $ c_gpiod_chip_watch_line_info ptr offset
  return $ LineInfo <$> res   

-- | Stop watching a line offset for status change events.
--
-- Disables notifications previously initiated via 'chipWatchLineInfo'.
chipUnwatchLineInfo :: Chip -> LineOffset -> IO (Either Errno ())
chipUnwatchLineInfo (Chip ptr) offset = do
  checkMinusOne $ c_gpiod_chip_unwatch_line_info ptr offset

-- | Retrieve the underlying Linux file descriptor ('Fd') associated with an open t'Chip.
--
-- Can be passed to event loops ('GHC.Event', @epoll@, @select@, etc.) to monitor line watch events.
chipFd :: Chip -> IO Fd
chipFd (Chip ptr) = c_gpiod_chip_get_fd ptr

-- | Wait for status change events on any of the watched lines on the chip.
--
-- Accepts a t'TimeoutNs parameter ('Immediate', 'Infinite', or 'Nanoseconds').
-- Returns 'Right' 'EventReady' if an event is available to read, or 'Right' 'Timeout' if timed out.
chipWaitInfoEvent :: Chip -> TimeoutNs -> IO (Either Errno WaitResult)
chipWaitInfoEvent (Chip ptr) ns = do
  res <- c_gpiod_chip_wait_info_event ptr (fromIntegral $ timeoutNsToC ns)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout
  
-- | Read a single line status change event (t'InfoEvent) from the chip.
--
-- Should be called when 'chipWaitInfoEvent' indicates 'EventReady'.
-- The caller must free the returned t'InfoEvent with 'infoEventFree'.
chipReadInfoEvent :: Chip -> IO (Either Errno InfoEvent)
chipReadInfoEvent (Chip ptr) = do
  res <- checkNull $ c_gpiod_chip_read_info_event ptr 
  return $ InfoEvent <$> res   

-- | Look up the zero-based line offset index on the chip given a pin name string.
--
-- Returns 'Right' t'LineOffset if the pin name exists, or 'Left' 'Errno' (e.g. 'Foreign.C.Error.eENOENT') if not found.
chipLineOffsetFromName :: Chip -> ByteString -> IO (Either Errno LineOffset)
chipLineOffsetFromName (Chip ptr) name = do
  res <- BS.useAsCString name $ \cStr -> c_gpiod_chip_get_line_offset_from_name ptr cStr
  if res == -1 
    then Left <$> getErrno 
    else return $ Right $ LineOffset (fromIntegral res)

-- | Request exclusive kernel control over a collection of lines on the chip.
--
-- Takes optional t'RequestConfig (consumer label, event buffer size) and mandatory t'LineConfig (settings mapped to offsets).
-- Returns 'Right' t'LineRequest on success. The handle must be released with 'lineRequestRelease'.
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

-- | Free a t'ChipInfo structure allocated by 'chipInfo'.
chipInfoFree :: ChipInfo -> IO ()
chipInfoFree (ChipInfo info) = c_gpiod_chip_info_free info 

-- | Retrieve the kernel device name string of the chip (e.g. @"gpiochip4"@).
chipInfoName :: ChipInfo -> IO ByteString
chipInfoName (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_name info
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Retrieve the hardware controller label string of the chip (e.g. @"pinctrl-bcm2835"@).
chipInfoLabel :: ChipInfo -> IO ByteString
chipInfoLabel (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_label info
  if res == nullPtr
    then return BS.empty
    else BS.packCString res

-- | Retrieve the total number of GPIO lines exposed by the chip.
chipInfoNumLines :: ChipInfo -> IO Word 
chipInfoNumLines (ChipInfo info) = do
  res <- c_gpiod_chip_info_get_num_lines info
  return $ fromIntegral res

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

-- | Free a t'LineInfo snapshot structure allocated by 'chipLineInfo', 'chipWatchLineInfo', or 'infoEventLineInfo'.
lineInfoFree :: LineInfo -> IO ()
lineInfoFree (LineInfo info) = c_gpiod_line_info_free info

-- | Duplicate a t'LineInfo object. The copy must be freed separately with 'lineInfoFree'.
lineInfoCopy :: LineInfo -> IO (Either Errno LineInfo)
lineInfoCopy (LineInfo info) = do
  res <- checkNull (c_gpiod_line_info_copy info)
  return $ LineInfo <$> res

-- | Retrieve the zero-based line offset index from a t'LineInfo snapshot.
lineInfoOffset :: LineInfo -> IO LineOffset
lineInfoOffset (LineInfo info) = c_gpiod_line_info_get_offset info

-- | Retrieve the name of the GPIO line, or 'Nothing' if unnamed in device tree / specs.
lineInfoName :: LineInfo -> IO (Maybe ByteString)
lineInfoName (LineInfo info) = do
  res <- c_gpiod_line_info_get_name info
  if res == nullPtr
    then return Nothing
    else Just <$> BS.packCString res 

-- | Check whether the line is currently in use / claimed by a driver or consumer.
lineInfoIsUsed :: LineInfo -> IO Bool
lineInfoIsUsed (LineInfo info) = do
  res <- c_gpiod_line_info_is_used info
  return $ toBool res

-- | Retrieve the consumer identification string of the entity using the line, or 'Nothing' if unclaimed.
lineInfoConsumer :: LineInfo -> IO (Maybe ByteString)
lineInfoConsumer (LineInfo info) = do
  name <- c_gpiod_line_info_get_consumer info
  if name == nullPtr
    then return Nothing
    else Just <$> BS.packCString name

-- | Query the line direction setting ('DirInput' or 'DirOutput').
lineInfoDirection :: LineInfo -> IO LineDirection
lineInfoDirection (LineInfo info) = c_gpiod_line_info_get_direction info

-- | Query the line edge detection mode ('EdgeNone', 'EdgeRising', 'EdgeFalling', 'EdgeBoth').
lineInfoEdgeDetection :: LineInfo -> IO LineEdge
lineInfoEdgeDetection (LineInfo info) = c_gpiod_line_info_get_edge_detection info

-- | Query internal pull resistor bias ('BiasDisabled', 'BiasPullUp', 'BiasPullDown', etc.).
lineInfoBias :: LineInfo -> IO LineBias
lineInfoBias (LineInfo info) = c_gpiod_line_info_get_bias info

-- | Query output driver mode ('PushPull', 'OpenDrain', 'OpenSource').
lineInfoDrive :: LineInfo -> IO LineDrive
lineInfoDrive (LineInfo info) = c_gpiod_line_info_get_drive info

-- | Check if active-low signal inversion is enabled on this line.
lineInfoIsActiveLow :: LineInfo -> IO Bool
lineInfoIsActiveLow (LineInfo info) = do
  res <- c_gpiod_line_info_is_active_low info
  return $ toBool res

-- | Check if hardware/kernel input debounce filtering is enabled for this line.
lineInfoIsDebounced :: LineInfo -> IO Bool
lineInfoIsDebounced (LineInfo info) = do
  res <- c_gpiod_line_info_is_debounced info
  return $ toBool res

-- | Query the input debounce period in microseconds (0 if debouncing is disabled).
lineInfoDebouncePeriod :: LineInfo -> IO Word  
lineInfoDebouncePeriod (LineInfo info) = do
  res <- c_gpiod_line_info_get_debounce_period_us info
  return $ fromIntegral res

-- | Query the timestamp clock source used for line edge events ('Monotonic', 'Realtime', 'Hardware').
lineInfoEventClock :: LineInfo -> IO LineClock
lineInfoEventClock (LineInfo info) = c_gpiod_line_info_get_event_clock info

--------------------------------------------------------------------------------
-- 5. LINE WATCH (INFO EVENT) 
--------------------------------------------------------------------------------

-- | Free an t'InfoEvent structure allocated by 'chipReadInfoEvent'.
infoEventFree :: InfoEvent -> IO ()
infoEventFree (InfoEvent event) = c_gpiod_info_event_free event 

-- | Query event classification ('LineRequested', 'LineReleased', or 'LineConfigChanged').
infoEventType :: InfoEvent -> IO InfoEventType
infoEventType (InfoEvent event) = c_gpiod_info_event_get_event_type event 

-- | Query timestamp (in nanoseconds) when the line status event occurred.
infoEventTimestamp :: InfoEvent -> IO TimestampNs 
infoEventTimestamp (InfoEvent event) = c_gpiod_info_event_get_timestamp_ns event

-- | Extract a line info snapshot (t'LineInfo) representing updated state at event time.
infoEventLineInfo :: InfoEvent -> IO LineInfo
infoEventLineInfo (InfoEvent event) = LineInfo <$> c_gpiod_info_event_get_line_info event
  
--------------------------------------------------------------------------------
-- 6. LINE SETTINGS
--------------------------------------------------------------------------------

-- | Allocate a new t'LineSettings object with default attributes.
--
-- Must be freed with 'lineSettingsFree' when finished.
lineSettingsNew :: IO (Either Errno LineSettings)
lineSettingsNew = do 
  res <- checkNull c_gpiod_line_settings_new
  return $ LineSettings <$> res 

-- | Free a t'LineSettings object and release associated resources.
lineSettingsFree :: LineSettings -> IO ()
lineSettingsFree (LineSettings settings) = c_gpiod_line_settings_free settings 

-- | Reset a t'LineSettings object back to default values.
lineSettingsReset :: LineSettings -> IO ()
lineSettingsReset (LineSettings settings) = c_gpiod_line_settings_reset settings 

-- | Duplicate a t'LineSettings object. The copy must be freed with 'lineSettingsFree'.
lineSettingsCopy :: LineSettings -> IO (Either Errno LineSettings)
lineSettingsCopy (LineSettings settings) = do
  res <- checkNull (c_gpiod_line_settings_copy settings)
  return $ LineSettings <$> res

-- | Set the line pin direction ('DirInput', 'DirOutput', 'DirAsIs') in settings.
lineSettingsSetDirection :: LineSettings -> LineDirection -> IO (Either Errno ())
lineSettingsSetDirection (LineSettings settings) dir =
  checkMinusOne $ c_gpiod_line_settings_set_direction settings dir
  
-- | Get the line pin direction in settings.
lineSettingsDirection :: LineSettings -> IO LineDirection
lineSettingsDirection (LineSettings settings) = c_gpiod_line_settings_get_direction settings

-- | Set edge detection mode ('EdgeNone', 'EdgeRising', 'EdgeFalling', 'EdgeBoth') in settings.
lineSettingsSetEdgeDetection :: LineSettings -> LineEdge -> IO (Either Errno ())
lineSettingsSetEdgeDetection (LineSettings settings) edge =
  checkMinusOne $ c_gpiod_line_settings_set_edge_detection settings edge

-- | Get edge detection mode from settings.
lineSettingsEdgeDetection :: LineSettings -> IO LineEdge
lineSettingsEdgeDetection (LineSettings settings) = c_gpiod_line_settings_get_edge_detection settings

-- | Set internal pull bias ('BiasDisabled', 'BiasPullUp', 'BiasPullDown', 'BiasAsIs') in settings.
lineSettingsSetBias :: LineSettings -> LineBias -> IO (Either Errno ())
lineSettingsSetBias (LineSettings settings) bias =
  checkMinusOne $ c_gpiod_line_settings_set_bias settings bias

-- | Get internal pull bias from settings.
lineSettingsBias :: LineSettings -> IO LineBias
lineSettingsBias (LineSettings settings) = c_gpiod_line_settings_get_bias settings

-- | Set output driver mode ('PushPull', 'OpenDrain', 'OpenSource') in settings.
lineSettingsSetDrive :: LineSettings -> LineDrive -> IO (Either Errno ())
lineSettingsSetDrive (LineSettings settings) drive =
  checkMinusOne $ c_gpiod_line_settings_set_drive settings drive

-- | Get output driver mode from settings.
lineSettingsDrive :: LineSettings -> IO LineDrive
lineSettingsDrive (LineSettings settings) = c_gpiod_line_settings_get_drive settings

-- | Set event timestamp clock source ('Monotonic', 'Realtime', 'Hardware') in settings.
lineSettingsSetEventClock :: LineSettings -> LineClock -> IO (Either Errno ())
lineSettingsSetEventClock (LineSettings settings) clock =
  checkMinusOne $ c_gpiod_line_settings_set_event_clock settings clock

-- | Get event timestamp clock source from settings.
lineSettingsEventClock :: LineSettings -> IO LineClock
lineSettingsEventClock (LineSettings settings) = c_gpiod_line_settings_get_event_clock settings

-- | Set active-low signal inversion flag in settings.
lineSettingsSetActiveLow :: LineSettings -> Bool -> IO ()
lineSettingsSetActiveLow (LineSettings settings) activeLow =
  c_gpiod_line_settings_set_active_low settings (if activeLow then 1 else 0)

-- | Get active-low signal inversion flag from settings.
lineSettingsActiveLow :: LineSettings -> IO Bool
lineSettingsActiveLow (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_active_low settings
  return $ toBool res

-- | Set input debounce period in microseconds in settings.
lineSettingsSetDebouncePeriodUs :: LineSettings -> Word -> IO ()
lineSettingsSetDebouncePeriodUs (LineSettings settings) us =
  c_gpiod_line_settings_set_debounce_period_us settings (fromIntegral us)

-- | Get input debounce period in microseconds from settings.
lineSettingsDebouncePeriodUs :: LineSettings -> IO Word
lineSettingsDebouncePeriodUs (LineSettings settings) = do
  res <- c_gpiod_line_settings_get_debounce_period_us settings
  return $ fromIntegral res

-- | Set initial output value ('LineActive' or 'LineInactive') in settings.
lineSettingsSetOutputValue :: LineSettings -> LineValue -> IO (Either Errno ())
lineSettingsSetOutputValue (LineSettings settings) val =
  checkMinusOne $ c_gpiod_line_settings_set_output_value settings val

-- | Get output value from settings.
lineSettingsOutputValue :: LineSettings -> IO LineValue
lineSettingsOutputValue (LineSettings settings) = c_gpiod_line_settings_get_output_value settings

--------------------------------------------------------------------------------
-- 7. LINE CONFIGURATION
--------------------------------------------------------------------------------

-- | Allocate a new t'LineConfig accumulator object.
--
-- Must be freed with 'lineConfigFree' when finished.
lineConfigNew :: IO (Either Errno LineConfig)
lineConfigNew = do  
  res <- checkNull c_gpiod_line_config_new 
  return $ LineConfig <$> res

-- | Free a t'LineConfig object.
lineConfigFree :: LineConfig -> IO ()
lineConfigFree (LineConfig config) = c_gpiod_line_config_free config

-- | Reset a t'LineConfig object, clearing all associated line settings.
lineConfigReset :: LineConfig -> IO ()
lineConfigReset (LineConfig config) = c_gpiod_line_config_reset config

-- | Associate a set of t'LineOffset's (as a Storable 'Vector') with a t'LineSettings configuration.
lineConfigAddLineSettings :: LineConfig -> Vector LineOffset -> LineSettings -> IO (Either Errno ())
lineConfigAddLineSettings (LineConfig config) offsets (LineSettings settings) = do
  let size = fromIntegral (V.length offsets)
  checkMinusOne $ V.unsafeWith offsets $ \ptr -> 
    c_gpiod_line_config_add_line_settings config ptr size settings

-- | Fetch a copy of the t'LineSettings configured for a specific line offset.
lineConfigLineSettings :: LineConfig -> LineOffset -> IO (Either Errno LineSettings)
lineConfigLineSettings (LineConfig config) offset = do
  res <- checkNull $ c_gpiod_line_config_get_line_settings config offset
  return $ LineSettings <$> res 

-- | Override output values for lines configured in t'LineConfig using a Storable 'Vector' of t'LineValue's.
lineConfigSetOutputValues :: LineConfig -> Vector LineValue -> IO (Either Errno ())
lineConfigSetOutputValues (LineConfig config) values = do
  let size = fromIntegral (V.length values)
  checkMinusOne $ V.unsafeWith values $ \ptr ->
    c_gpiod_line_config_set_output_values config ptr size

-- | Query total count of distinct line offsets configured within a t'LineConfig object.
lineConfigNumOffsets :: LineConfig -> IO Word  
lineConfigNumOffsets (LineConfig config) =
  fromIntegral <$> c_gpiod_line_config_get_num_configured_offsets config 

-- | Retrieve all configured line offsets stored in t'LineConfig as a Storable 'Vector'.
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

-- | Allocate a new t'RequestConfig object.
--
-- Must be freed with 'requestConfigFree' when finished.
requestConfigNew :: IO (Either Errno RequestConfig)
requestConfigNew = do  
  res <- checkNull c_gpiod_request_config_new  
  return $ RequestConfig <$> res 

-- | Free a t'RequestConfig object.
requestConfigFree :: RequestConfig -> IO()
requestConfigFree (RequestConfig config) = c_gpiod_request_config_free config

-- | Set the consumer identification string (e.g. @"my-app"@) in a t'RequestConfig.
requestConfigSetConsumer :: RequestConfig -> ByteString -> IO()
requestConfigSetConsumer (RequestConfig config) name =
  BS.useAsCString name $ \cStr -> do 
    c_gpiod_request_config_set_consumer config cStr
  
-- | Get the consumer identification string from a t'RequestConfig.
requestConfigConsumer :: RequestConfig -> IO ByteString
requestConfigConsumer (RequestConfig config) = do
  res <- c_gpiod_request_config_get_consumer config
  BS.packCString res 
    
-- | Set the size of kernel event buffer (in number of events) in a t'RequestConfig.
requestConfigSetEventBufferSize :: RequestConfig -> Word -> IO ()
requestConfigSetEventBufferSize (RequestConfig config) size =
  c_gpiod_request_config_set_event_buffer_size config (fromIntegral size)

-- | Get the size of kernel event buffer (in number of events) from a t'RequestConfig.
requestConfigEventBufferSize :: RequestConfig -> IO Word
requestConfigEventBufferSize (RequestConfig config) =
  fromIntegral <$> c_gpiod_request_config_get_event_buffer_size config

--------------------------------------------------------------------------------
-- 9. LINE REQUEST
--------------------------------------------------------------------------------

-- | Release claimed GPIO lines and close the line request object.
lineRequestRelease :: LineRequest -> IO ()
lineRequestRelease (LineRequest request) = c_gpiod_line_request_release request

-- | Retrieve the name of the GPIO chip on which this request was created.
lineRequestChipName :: LineRequest -> IO ByteString
lineRequestChipName (LineRequest request) = do
  res <- c_gpiod_line_request_get_chip_name request
  BS.packCString res  
  
-- | Query total count of lines claimed in this request.
lineRequestNumLines :: LineRequest -> IO Word 
lineRequestNumLines (LineRequest request) = 
  fromIntegral <$> c_gpiod_line_request_get_num_requested_lines request 

-- | Retrieve all line offsets claimed by this request as a Storable 'Vector'.
lineRequestRequestedOffsets :: LineRequest -> IO (Vector LineOffset)
lineRequestRequestedOffsets (LineRequest request) = do
  num <- c_gpiod_line_request_get_num_requested_lines request
  vec <- MV.new (fromIntegral num)
  _ <- MV.unsafeWith vec $ \ptr ->
    c_gpiod_line_request_get_requested_offsets request ptr num
  V.unsafeFreeze vec

-- | Read the logical value ('LineActive' or 'LineInactive') of a single requested line offset.
lineRequestValue :: LineRequest -> LineOffset -> IO (Either Errno LineValue)
lineRequestValue (LineRequest request) offset = do
  lineValue <- c_gpiod_line_request_get_value request offset
  if lineValue == LineError
    then Left <$> getErrno
    else return $ Right lineValue

-- | Read logical values for a subset of requested lines into a Storable 'Vector'.
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

-- | Read logical values for all requested lines into a Storable 'Vector'.
lineRequestValues :: LineRequest -> IO (Either Errno (Vector LineValue))
lineRequestValues (LineRequest request) = do
  numLines <- c_gpiod_line_request_get_num_requested_lines request
  mutValues <- MV.new (fromIntegral numLines)
  res <- MV.unsafeWith mutValues $ \valuesPtr ->
    c_gpiod_line_request_get_values request valuesPtr
  if res == -1
    then Left <$> getErrno
    else Right <$> V.unsafeFreeze mutValues

-- | Set the logical value ('LineActive' or 'LineInactive') of a single requested line offset.
lineRequestSetValue :: LineRequest -> LineOffset -> LineValue -> IO (Either Errno ())
lineRequestSetValue _ _ LineError = return (Left eINVAL)
lineRequestSetValue (LineRequest request) offset value =
  checkMinusOne $ c_gpiod_line_request_set_value request offset value

-- | Set logical values for a subset of requested lines from Storable 'Vector's of offsets and values.
lineRequestSetValuesSubset :: LineRequest -> Vector LineOffset -> Vector LineValue -> IO (Either Errno ())
lineRequestSetValuesSubset (LineRequest request) offsets values
  | V.length offsets /= V.length values = return (Left eINVAL)
  | otherwise =
      let numValues = V.length offsets
      in V.unsafeWith offsets $ \offsetsPtr ->
           V.unsafeWith values $ \valuesPtr ->
             checkMinusOne $ c_gpiod_line_request_set_values_subset request (fromIntegral numValues) offsetsPtr valuesPtr

-- | Set logical values for all requested lines from a Storable 'Vector'.
lineRequestSetValues :: LineRequest -> Vector LineValue -> IO (Either Errno ())
lineRequestSetValues (LineRequest request) values =
  V.unsafeWith values $ \valuesPtr ->
    checkMinusOne $ c_gpiod_line_request_set_values request valuesPtr

-- | Update line configurations (direction, edge detection, output values) of existing requested lines.
lineRequestReconfigure :: LineRequest -> LineConfig -> IO (Either Errno ())
lineRequestReconfigure (LineRequest request) (LineConfig config) =
  checkMinusOne $ c_gpiod_line_request_reconfigure_lines request config  

-- | Retrieve file descriptor ('Fd') associated with the active line request for event looping.
lineRequestFd :: LineRequest -> IO Fd
lineRequestFd (LineRequest request) = c_gpiod_line_request_get_fd request

-- | Wait for hardware edge events to occur on requested input lines.
--
-- Takes a t'TimeoutNs parameter. Returns 'Right' 'EventReady' if events are ready to read.
lineRequestWaitEdgeEvents :: LineRequest -> TimeoutNs -> IO (Either Errno WaitResult)
lineRequestWaitEdgeEvents (LineRequest request) timeoutNs = do
  res <- c_gpiod_line_request_wait_edge_events request (timeoutNsToC timeoutNs)
  if res == -1
    then Left <$> getErrno
    else case res of
      1 -> return $ Right EventReady
      0 -> return $ Right Timeout
      _ -> return $ Right Timeout

-- | Read up to @maxEvents@ edge events from a line request into an t'EventBuffer.
--
-- Returns 'Right' 'Int' containing the number of events read into the buffer.
lineRequestReadEdgeEvents :: LineRequest -> EventBuffer -> Word -> IO (Either Errno Int)
lineRequestReadEdgeEvents (LineRequest reqPtr) (EventBuffer bufPtr) maxEvents = do
  count <- c_gpiod_line_request_read_edge_events reqPtr bufPtr (fromIntegral maxEvents)
  if count == -1
    then Left <$> getErrno
    else return $ Right (fromIntegral count)

--------------------------------------------------------------------------------
-- 10. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

-- | Free a t'RawEdgeEvent object.
rawEdgeEventFree :: RawEdgeEvent -> IO ()
rawEdgeEventFree (RawEdgeEvent event) = c_gpiod_edge_event_free event

-- | Duplicate a t'RawEdgeEvent. The copy must be freed with 'rawEdgeEventFree'.
rawEdgeEventCopy :: RawEdgeEvent -> IO (Either Errno RawEdgeEvent)
rawEdgeEventCopy (RawEdgeEvent event) = do
  res <- checkNull (c_gpiod_edge_event_copy event)
  return $ RawEdgeEvent <$> res

-- | Extract event edge type ('Rising' or 'Falling') from a raw edge event pointer.
rawEdgeEventType :: RawEdgeEvent -> IO EdgeEventType
rawEdgeEventType (RawEdgeEvent event) = c_gpiod_edge_event_get_event_type event

-- | Extract event timestamp (in nanoseconds) from a raw edge event pointer.
rawEdgeEventTimestampNs :: RawEdgeEvent -> IO TimestampNs
rawEdgeEventTimestampNs (RawEdgeEvent event) = c_gpiod_edge_event_get_timestamp_ns event

-- | Retrieve the zero-based line offset index that triggered the edge event.
rawEdgeEventLineOffset :: RawEdgeEvent -> IO LineOffset
rawEdgeEventLineOffset (RawEdgeEvent event) = c_gpiod_edge_event_get_line_offset event 

-- | Retrieve the global event sequence number across all lines on the GPIO chip.
rawEdgeEventGlobalSeqNo :: RawEdgeEvent -> IO Word64 
rawEdgeEventGlobalSeqNo (RawEdgeEvent event) =
  fromIntegral <$> c_gpiod_edge_event_get_global_seqno event  

-- | Retrieve the line-specific event sequence number.
rawEdgeEventLineSeqNo :: RawEdgeEvent -> IO LineOffset
rawEdgeEventLineSeqNo (RawEdgeEvent event) = c_gpiod_edge_event_get_line_seqno event  

-- | Allocate a new t'EventBuffer with the specified capacity.
--
-- Must be freed with 'eventBufferFree'.
eventBufferNew :: Word -> IO (Either Errno EventBuffer)
eventBufferNew cap = do
  res <- checkNull $ c_gpiod_edge_event_buffer_new (fromIntegral cap)
  return $ EventBuffer <$> res

-- | Query the maximum capacity of an t'EventBuffer.
eventBufferCapacity :: EventBuffer -> IO Word
eventBufferCapacity (EventBuffer buffer) =
  fromIntegral <$> c_gpiod_edge_event_buffer_get_capacity buffer 

-- | Free an t'EventBuffer and release associated memory.
eventBufferFree :: EventBuffer -> IO ()
eventBufferFree (EventBuffer buffer) = c_gpiod_edge_event_buffer_free buffer 

-- | Retrieve a raw edge event pointer from the buffer by zero-based index.
eventBufferGetEvent :: EventBuffer -> Word -> IO (Either Errno RawEdgeEvent)
eventBufferGetEvent (EventBuffer buffer) idx = do
  res <- checkNull (c_gpiod_edge_event_buffer_get_event buffer (fromIntegral idx))
  return $ RawEdgeEvent <$> res

-- | Query the number of edge events currently populated in the buffer.
eventBufferNumEvents :: EventBuffer -> IO Word
eventBufferNumEvents (EventBuffer buffer) =
  fromIntegral <$> c_gpiod_edge_event_buffer_get_num_events buffer  

--------------------------------------------------------------------------------
-- 11. UTILITIES
--------------------------------------------------------------------------------

-- | Check whether the filesystem path (e.g. @"/dev/gpiochip4"@) refers to a valid GPIO chip character device node.
isGPIOChip :: ByteString -> IO Bool
isGPIOChip path = do
  BS.useAsCString path (fmap toBool . c_gpiod_is_gpiochip_device)

-- | Retrieve the version string of the underlying C @libgpiod@ library (e.g. @"2.1"@).
gpiodAPIVersion :: IO ByteString
gpiodAPIVersion = do
  ver <- c_gpiod_api_version
  if ver == nullPtr
    then return BS.empty
    else BS.packCString ver
