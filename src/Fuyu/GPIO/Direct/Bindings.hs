{-# LANGUAGE ForeignFunctionInterface #-}
-- |
-- Module      : Fuyu.GPIO.Direct.Bindings
-- Description : Low-level FFI bindings to C libgpiod v2 symbols.
-- Maintainer  : BassGT
-- Portability : POSIX (Linux GPIO character device interface)
--
-- Raw Foreign Function Interface (FFI) bindings for @libgpiod v2@ C API functions.
-- These bindings operate directly on raw 'Ptr' pointers and C types. Higher-level
-- Haskell wrappers with automatic error conversion and type safety are provided in
-- "Fuyu.GPIO.Direct".
module Fuyu.GPIO.Direct.Bindings where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CLong(..), CSize(..), CUInt(..), CULong(..), CBool(..))
import Foreign.Ptr (Ptr)
import Fuyu.GPIO.Direct.Types
import Data.Int (Int64)
import System.Posix.Types (Fd(..))

--------------------------------------------------------------------------------
-- 1. CHIP MANAGEMENT
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_chip_open@. Opens a GPIO chip at the given filesystem path.
-- Returns a NULL pointer on failure.
foreign import ccall "gpiod_chip_open"
  c_gpiod_chip_open :: CString -> IO (Ptr CGpiodChip)

-- | Raw C call to @gpiod_chip_close@. Closes the chip and frees associated C resources.
foreign import ccall "gpiod_chip_close"
  c_gpiod_chip_close :: Ptr CGpiodChip -> IO ()

-- | Raw C call to @gpiod_chip_get_info@. Retrieves static chip information.
-- Returns a pointer to 'CGpiodChipInfo' which must be freed with 'c_gpiod_chip_info_free'.
foreign import ccall "gpiod_chip_get_info"
  c_gpiod_chip_get_info :: Ptr CGpiodChip -> IO (Ptr CGpiodChipInfo) 

-- | Raw C call to @gpiod_chip_get_path@. Returns the filesystem path used to open the chip.
foreign import ccall "gpiod_chip_get_path"
  c_gpiod_chip_get_path :: Ptr CGpiodChip -> IO CString  

-- | Raw C call to @gpiod_chip_get_line_info@. Fetches line info snapshot for an offset.
-- Returns a pointer to 'CGpiodLineInfo' which must be freed with 'c_gpiod_line_info_free'.
foreign import ccall "gpiod_chip_get_line_info"
  c_gpiod_chip_get_line_info :: Ptr CGpiodChip -> LineOffset -> IO (Ptr CGpiodLineInfo) 

-- | Raw C call to @gpiod_chip_watch_line_info@. Fetches line info snapshot and enables line status watching.
foreign import ccall "gpiod_chip_watch_line_info"
  c_gpiod_chip_watch_line_info :: Ptr CGpiodChip -> LineOffset -> IO (Ptr CGpiodLineInfo) 

-- | Raw C call to @gpiod_chip_unwatch_line_info@. Disables status watching for the specified line offset.
-- Returns 0 on success, -1 on failure.
foreign import ccall "gpiod_chip_unwatch_line_info"
  c_gpiod_chip_unwatch_line_info :: Ptr CGpiodChip -> LineOffset -> IO CInt

-- | Raw C call to @gpiod_chip_get_fd@. Returns the file descriptor of the opened chip.
foreign import ccall "gpiod_chip_get_fd"
  c_gpiod_chip_get_fd :: Ptr CGpiodChip -> IO Fd

-- | Raw C call to @gpiod_chip_wait_info_event@. Waits for status change events on watched lines.
-- Timeout parameter is in nanoseconds (-1 for infinite, 0 for non-blocking).
-- Returns 1 if an event is ready, 0 on timeout, -1 on failure.
foreign import ccall "gpiod_chip_wait_info_event"
  c_gpiod_chip_wait_info_event :: Ptr CGpiodChip -> Int64 -> IO CInt 

-- | Raw C call to @gpiod_chip_read_info_event@. Reads an info change event from the chip.
-- Returns a pointer to 'CGpiodInfoEvent' which must be freed with 'c_gpiod_info_event_free'.
foreign import ccall "gpiod_chip_read_info_event"
  c_gpiod_chip_read_info_event :: Ptr CGpiodChip -> IO (Ptr CGpiodInfoEvent)

-- | Raw C call to @gpiod_chip_request_lines@. Requests a set of lines configured by line/request configs.
-- Returns a pointer to 'CGpiodLineRequest' or NULL on error.
foreign import ccall "gpiod_chip_request_lines"
  c_gpiod_chip_request_lines :: Ptr CGpiodChip 
                             -> Ptr CGpiodRequestConfig
                             -> Ptr CGpiodLineConfig
                             -> IO (Ptr CGpiodLineRequest)

-- | Raw C call to @gpiod_chip_get_line_offset_from_name@. Looks up line offset by pin name.
-- Returns line offset integer >= 0 on success, or -1 on failure.
foreign import ccall "gpiod_chip_get_line_offset_from_name"
  c_gpiod_chip_get_line_offset_from_name :: Ptr CGpiodChip -> CString -> IO CInt

--------------------------------------------------------------------------------
-- 2. CHIP INFO
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_chip_info_free@. Frees a chip info object.
foreign import ccall "gpiod_chip_info_free"
  c_gpiod_chip_info_free :: Ptr CGpiodChipInfo -> IO ()

-- | Raw C call to @gpiod_chip_info_get_name@. Gets chip device name (e.g. "gpiochip4").
foreign import ccall "gpiod_chip_info_get_name"
  c_gpiod_chip_info_get_name :: Ptr CGpiodChipInfo -> IO CString

-- | Raw C call to @gpiod_chip_info_get_label@. Gets hardware controller label string.
foreign import ccall "gpiod_chip_info_get_label"
  c_gpiod_chip_info_get_label :: Ptr CGpiodChipInfo -> IO CString  

-- | Raw C call to @gpiod_chip_info_get_num_lines@. Gets total count of GPIO lines on chip.
foreign import ccall "gpiod_chip_info_get_num_lines"
  c_gpiod_chip_info_get_num_lines :: Ptr CGpiodChipInfo -> IO CSize 

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_line_info_free@. Frees a line info object.
foreign import ccall "gpiod_line_info_free"
  c_gpiod_line_info_free :: Ptr CGpiodLineInfo -> IO ()

-- | Raw C call to @gpiod_line_info_copy@. Duplicates a line info object.
foreign import ccall "gpiod_line_info_copy"
  c_gpiod_line_info_copy :: Ptr CGpiodLineInfo -> IO (Ptr CGpiodLineInfo)

-- | Raw C call to @gpiod_line_info_get_offset@. Returns zero-based line offset index.
foreign import ccall "gpiod_line_info_get_offset"
  c_gpiod_line_info_get_offset :: Ptr CGpiodLineInfo -> IO LineOffset

-- | Raw C call to @gpiod_line_info_get_name@. Returns pin name string, or NULL if unnamed.
foreign import ccall "gpiod_line_info_get_name"
  c_gpiod_line_info_get_name :: Ptr CGpiodLineInfo -> IO CString

-- | Raw C call to @gpiod_line_info_is_used@. Checks if line is requested by any process/kernel consumer.
foreign import ccall "gpiod_line_info_is_used"
  c_gpiod_line_info_is_used :: Ptr CGpiodLineInfo -> IO CBool

-- | Raw C call to @gpiod_line_info_get_consumer@. Gets consumer label string, or NULL if unused.
foreign import ccall "gpiod_line_info_get_consumer"
  c_gpiod_line_info_get_consumer :: Ptr CGpiodLineInfo -> IO CString

-- | Raw C call to @gpiod_line_info_get_direction@. Gets direction configuration of line.
foreign import ccall "gpiod_line_info_get_direction"
  c_gpiod_line_info_get_direction :: Ptr CGpiodLineInfo -> IO LineDirection

-- | Raw C call to @gpiod_line_info_get_edge_detection@. Gets edge detection mode of line.
foreign import ccall "gpiod_line_info_get_edge_detection"
  c_gpiod_line_info_get_edge_detection :: Ptr CGpiodLineInfo -> IO LineEdge

-- | Raw C call to @gpiod_line_info_get_bias@. Gets internal pull bias setting of line.
foreign import ccall "gpiod_line_info_get_bias"
  c_gpiod_line_info_get_bias :: Ptr CGpiodLineInfo -> IO LineBias

-- | Raw C call to @gpiod_line_info_get_drive@. Gets output drive configuration of line.
foreign import ccall "gpiod_line_info_get_drive"
  c_gpiod_line_info_get_drive :: Ptr CGpiodLineInfo -> IO LineDrive

-- | Raw C call to @gpiod_line_info_is_active_low@. Checks active-low flag.
foreign import ccall "gpiod_line_info_is_active_low"
  c_gpiod_line_info_is_active_low :: Ptr CGpiodLineInfo -> IO CBool  

-- | Raw C call to @gpiod_line_info_is_debounced@. Checks debounce filter flag.
foreign import ccall "gpiod_line_info_is_debounced"
  c_gpiod_line_info_is_debounced :: Ptr CGpiodLineInfo -> IO CBool  

-- | Raw C call to @gpiod_line_info_get_debounce_period_us@. Gets debounce period in microseconds.
foreign import ccall "gpiod_line_info_get_debounce_period_us"
  c_gpiod_line_info_get_debounce_period_us :: Ptr CGpiodLineInfo -> IO CULong

-- | Raw C call to @gpiod_line_info_get_event_clock@. Gets event timestamp clock source.
foreign import ccall "gpiod_line_info_get_event_clock"
  c_gpiod_line_info_get_event_clock :: Ptr CGpiodLineInfo -> IO LineClock

--------------------------------------------------------------------------------
-- 5. LINE WATCH (INFO EVENT)
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_info_event_free@. Frees an info event structure.
foreign import ccall "gpiod_info_event_free"
  c_gpiod_info_event_free :: Ptr CGpiodInfoEvent -> IO ()

-- | Raw C call to @gpiod_info_event_get_event_type@. Gets event type (requested, released, config changed).
foreign import ccall "gpiod_info_event_get_event_type"
  c_gpiod_info_event_get_event_type :: Ptr CGpiodInfoEvent -> IO InfoEventType

-- | Raw C call to @gpiod_info_event_get_timestamp_ns@. Gets event timestamp in nanoseconds.
foreign import ccall "gpiod_info_event_get_timestamp_ns"
  c_gpiod_info_event_get_timestamp_ns :: Ptr CGpiodInfoEvent -> IO TimestampNs

-- | Raw C call to @gpiod_info_event_get_line_info@. Reads line info pointer from event.
foreign import ccall "gpiod_info_event_get_line_info"
  c_gpiod_info_event_get_line_info :: Ptr CGpiodInfoEvent -> IO (Ptr CGpiodLineInfo)

--------------------------------------------------------------------------------
-- 6. LINE SETTINGS
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_line_settings_new@. Allocates new line settings object.
foreign import ccall "gpiod_line_settings_new"
  c_gpiod_line_settings_new :: IO (Ptr CGpiodLineSettings)

-- | Raw C call to @gpiod_line_settings_free@. Frees line settings object.
foreign import ccall "gpiod_line_settings_free"
  c_gpiod_line_settings_free :: Ptr CGpiodLineSettings -> IO ()

-- | Raw C call to @gpiod_line_settings_reset@. Resets settings object to default values.
foreign import ccall "gpiod_line_settings_reset"
  c_gpiod_line_settings_reset :: Ptr CGpiodLineSettings -> IO ()

-- | Raw C call to @gpiod_line_settings_copy@. Duplicates line settings object.
foreign import ccall "gpiod_line_settings_copy"
  c_gpiod_line_settings_copy :: Ptr CGpiodLineSettings -> IO (Ptr CGpiodLineSettings)

-- | Raw C call to @gpiod_line_settings_set_direction@. Sets line direction setting.
foreign import ccall "gpiod_line_settings_set_direction"
  c_gpiod_line_settings_set_direction :: Ptr CGpiodLineSettings -> LineDirection -> IO CInt      

-- | Raw C call to @gpiod_line_settings_get_direction@. Gets line direction setting.
foreign import ccall "gpiod_line_settings_get_direction"
  c_gpiod_line_settings_get_direction :: Ptr CGpiodLineSettings -> IO LineDirection

-- | Raw C call to @gpiod_line_settings_set_edge_detection@. Sets edge detection setting.
foreign import ccall "gpiod_line_settings_set_edge_detection"
  c_gpiod_line_settings_set_edge_detection :: Ptr CGpiodLineSettings -> LineEdge -> IO CInt 

-- | Raw C call to @gpiod_line_settings_get_edge_detection@. Gets edge detection setting.
foreign import ccall "gpiod_line_settings_get_edge_detection"
  c_gpiod_line_settings_get_edge_detection :: Ptr CGpiodLineSettings -> IO LineEdge 

-- | Raw C call to @gpiod_line_settings_set_bias@. Sets internal pull bias setting.
foreign import ccall "gpiod_line_settings_set_bias"
  c_gpiod_line_settings_set_bias :: Ptr CGpiodLineSettings -> LineBias -> IO CInt

-- | Raw C call to @gpiod_line_settings_get_bias@. Gets internal pull bias setting.
foreign import ccall "gpiod_line_settings_get_bias"
  c_gpiod_line_settings_get_bias :: Ptr CGpiodLineSettings -> IO LineBias

-- | Raw C call to @gpiod_line_settings_set_drive@. Sets driver output mode.
foreign import ccall "gpiod_line_settings_set_drive"
  c_gpiod_line_settings_set_drive :: Ptr CGpiodLineSettings -> LineDrive -> IO CInt

-- | Raw C call to @gpiod_line_settings_get_drive@. Gets driver output mode.
foreign import ccall "gpiod_line_settings_get_drive"
  c_gpiod_line_settings_get_drive :: Ptr CGpiodLineSettings -> IO LineDrive

-- | Raw C call to @gpiod_line_settings_set_active_low@. Sets active-low property flag.
foreign import ccall "gpiod_line_settings_set_active_low"
  c_gpiod_line_settings_set_active_low :: Ptr CGpiodLineSettings -> CBool -> IO ()  

-- | Raw C call to @gpiod_line_settings_get_active_low@. Gets active-low property flag.
foreign import ccall "gpiod_line_settings_get_active_low"
  c_gpiod_line_settings_get_active_low :: Ptr CGpiodLineSettings -> IO CBool

-- | Raw C call to @gpiod_line_settings_set_debounce_period_us@. Sets input debounce period (microseconds).
foreign import ccall "gpiod_line_settings_set_debounce_period_us"
  c_gpiod_line_settings_set_debounce_period_us :: Ptr CGpiodLineSettings -> CLong -> IO ()  

-- | Raw C call to @gpiod_line_settings_get_debounce_period_us@. Gets input debounce period (microseconds).
foreign import ccall "gpiod_line_settings_get_debounce_period_us"
  c_gpiod_line_settings_get_debounce_period_us :: Ptr CGpiodLineSettings -> IO CLong

-- | Raw C call to @gpiod_line_settings_set_event_clock@. Sets event clock source.
foreign import ccall "gpiod_line_settings_set_event_clock"
  c_gpiod_line_settings_set_event_clock :: Ptr CGpiodLineSettings -> LineClock -> IO CInt 

-- | Raw C call to @gpiod_line_settings_get_event_clock@. Gets event clock source.
foreign import ccall "gpiod_line_settings_get_event_clock"
  c_gpiod_line_settings_get_event_clock :: Ptr CGpiodLineSettings -> IO LineClock

-- | Raw C call to @gpiod_line_settings_set_output_value@. Sets initial output value setting.
foreign import ccall "gpiod_line_settings_set_output_value"
  c_gpiod_line_settings_set_output_value :: Ptr CGpiodLineSettings -> LineValue -> IO CInt 

-- | Raw C call to @gpiod_line_settings_get_output_value@. Gets output value setting.
foreign import ccall "gpiod_line_settings_get_output_value"
  c_gpiod_line_settings_get_output_value :: Ptr CGpiodLineSettings -> IO LineValue

--------------------------------------------------------------------------------
-- 7. LINE CONFIGURATION
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_line_config_new@. Allocates new line config accumulator.
foreign import ccall "gpiod_line_config_new"
  c_gpiod_line_config_new :: IO (Ptr CGpiodLineConfig)

-- | Raw C call to @gpiod_line_config_free@. Frees line config object.
foreign import ccall "gpiod_line_config_free"
  c_gpiod_line_config_free :: Ptr CGpiodLineConfig -> IO ()

-- | Raw C call to @gpiod_line_config_reset@. Clears line settings mapping in config object.
foreign import ccall "gpiod_line_config_reset"
  c_gpiod_line_config_reset :: Ptr CGpiodLineConfig -> IO ()

-- | Raw C call to @gpiod_line_config_add_line_settings@. Associates array of offsets with settings.
foreign import ccall "gpiod_line_config_add_line_settings"
  c_gpiod_line_config_add_line_settings :: Ptr CGpiodLineConfig
                                        -> Ptr LineOffset
                                        -> CSize
                                        -> Ptr CGpiodLineSettings 
                                        -> IO CInt

-- | Raw C call to @gpiod_line_config_get_line_settings@. Gets line settings associated with offset.
foreign import ccall "gpiod_line_config_get_line_settings"
  c_gpiod_line_config_get_line_settings :: Ptr CGpiodLineConfig -> LineOffset -> IO (Ptr CGpiodLineSettings)

-- | Raw C call to @gpiod_line_config_set_output_values@. Overrides output values for configured lines.
foreign import ccall "gpiod_line_config_set_output_values"
  c_gpiod_line_config_set_output_values :: Ptr CGpiodLineConfig -> Ptr LineValue -> CSize -> IO CInt

-- | Raw C call to @gpiod_line_config_get_num_configured_offsets@. Gets count of offsets in config.
foreign import ccall "gpiod_line_config_get_num_configured_offsets"
  c_gpiod_line_config_get_num_configured_offsets :: Ptr CGpiodLineConfig -> IO CSize

-- | Raw C call to @gpiod_line_config_get_configured_offsets@. Copies configured offsets into buffer array.
foreign import ccall "gpiod_line_config_get_configured_offsets"
  c_gpiod_line_config_get_configured_offsets :: Ptr CGpiodLineConfig -> Ptr LineOffset -> CSize -> IO CSize

--------------------------------------------------------------------------------
-- 8. REQUESTS CONFIG
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_request_config_new@. Allocates request configuration object.
foreign import ccall "gpiod_request_config_new"
  c_gpiod_request_config_new :: IO (Ptr CGpiodRequestConfig)

-- | Raw C call to @gpiod_request_config_free@. Frees request config object.
foreign import ccall "gpiod_request_config_free"
  c_gpiod_request_config_free :: Ptr CGpiodRequestConfig -> IO()

-- | Raw C call to @gpiod_request_config_set_consumer@. Sets consumer string in request config.
foreign import ccall "gpiod_request_config_set_consumer"
  c_gpiod_request_config_set_consumer :: Ptr CGpiodRequestConfig -> CString -> IO()

-- | Raw C call to @gpiod_request_config_get_consumer@. Reads consumer string from request config.
foreign import ccall "gpiod_request_config_get_consumer"
  c_gpiod_request_config_get_consumer :: Ptr CGpiodRequestConfig -> IO CString

-- | Raw C call to @gpiod_request_config_set_event_buffer_size@. Sets kernel event buffer size.
foreign import ccall "gpiod_request_config_set_event_buffer_size"
  c_gpiod_request_config_set_event_buffer_size :: Ptr CGpiodRequestConfig -> CSize -> IO()   

-- | Raw C call to @gpiod_request_config_get_event_buffer_size@. Gets kernel event buffer size.
foreign import ccall "gpiod_request_config_get_event_buffer_size"
  c_gpiod_request_config_get_event_buffer_size :: Ptr CGpiodRequestConfig -> IO CSize  

--------------------------------------------------------------------------------
-- 9. LINE REQUEST
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_line_request_release@. Releases requested lines and frees line request object.
foreign import ccall "gpiod_line_request_release"
  c_gpiod_line_request_release :: Ptr CGpiodLineRequest -> IO()

-- | Raw C call to @gpiod_line_request_get_chip_name@. Gets chip device name from request.
foreign import ccall "gpiod_line_request_get_chip_name"
  c_gpiod_line_request_get_chip_name :: Ptr CGpiodLineRequest -> IO CString

-- | Raw C call to @gpiod_line_request_get_num_requested_lines@. Gets count of lines in request.
foreign import ccall "gpiod_line_request_get_num_requested_lines"
  c_gpiod_line_request_get_num_requested_lines :: Ptr CGpiodLineRequest -> IO CSize

-- | Raw C call to @gpiod_line_request_get_requested_offsets@. Copies requested line offsets into buffer.
foreign import ccall "gpiod_line_request_get_requested_offsets"
  c_gpiod_line_request_get_requested_offsets :: Ptr CGpiodLineRequest -> Ptr LineOffset -> CSize -> IO CSize

-- | Raw C call to @gpiod_line_request_get_value@. Reads logical value of a single requested line.
foreign import ccall "gpiod_line_request_get_value"
  c_gpiod_line_request_get_value :: Ptr CGpiodLineRequest -> LineOffset -> IO LineValue 

-- | Raw C call to @gpiod_line_request_get_values_subset@. Reads logical values of a subset of lines.
foreign import ccall "gpiod_line_request_get_values_subset"
  c_gpiod_line_request_get_values_subset :: Ptr CGpiodLineRequest
                                         -> CSize
                                         -> Ptr LineOffset
                                         -> Ptr LineValue
                                         -> IO CInt

-- | Raw C call to @gpiod_line_request_get_values@. Reads logical values of all requested lines.
foreign import ccall "gpiod_line_request_get_values"
  c_gpiod_line_request_get_values :: Ptr CGpiodLineRequest -> Ptr LineValue -> IO CInt 

-- | Raw C call to @gpiod_line_request_set_value@. Sets logical value of a single line.
foreign import ccall "gpiod_line_request_set_value"
  c_gpiod_line_request_set_value :: Ptr CGpiodLineRequest -> LineOffset -> LineValue -> IO CInt 

-- | Raw C call to @gpiod_line_request_set_values_subset@. Sets logical values of a subset of lines.
foreign import ccall "gpiod_line_request_set_values_subset"
  c_gpiod_line_request_set_values_subset :: Ptr CGpiodLineRequest
                                          -> CSize
                                          -> Ptr LineOffset
                                          -> Ptr LineValue
                                          -> IO CInt

-- | Raw C call to @gpiod_line_request_set_values@. Sets logical values of all requested lines.
foreign import ccall "gpiod_line_request_set_values"
  c_gpiod_line_request_set_values :: Ptr CGpiodLineRequest -> Ptr LineValue -> IO CInt 

-- | Raw C call to @gpiod_line_request_reconfigure_lines@. Applies new configuration to requested lines.
foreign import ccall "gpiod_line_request_reconfigure_lines"
  c_gpiod_line_request_reconfigure_lines :: Ptr CGpiodLineRequest -> Ptr CGpiodLineConfig -> IO CInt  

-- | Raw C call to @gpiod_line_request_get_fd@. Returns file descriptor of the line request.
foreign import ccall "gpiod_line_request_get_fd"
  c_gpiod_line_request_get_fd :: Ptr CGpiodLineRequest -> IO Fd 

-- | Raw C call to @gpiod_line_request_wait_edge_events@. Waits for edge events on requested lines.
foreign import ccall "gpiod_line_request_wait_edge_events"
  c_gpiod_line_request_wait_edge_events :: Ptr CGpiodLineRequest -> CLong -> IO CInt

-- | Raw C call to @gpiod_line_request_read_edge_events@. Reads edge events from kernel buffer into EventBuffer.
foreign import ccall "gpiod_line_request_read_edge_events" 
  c_gpiod_line_request_read_edge_events :: Ptr CGpiodLineRequest -> Ptr CGpiodEdgeEventBuffer -> CSize -> IO CInt

--------------------------------------------------------------------------------
-- 10. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_edge_event_free@. Frees an edge event structure.
foreign import ccall "gpiod_edge_event_free"
  c_gpiod_edge_event_free :: Ptr CGpiodEdgeEvent -> IO ()

-- | Raw C call to @gpiod_edge_event_copy@. Duplicates an edge event.
foreign import ccall "gpiod_edge_event_copy"
  c_gpiod_edge_event_copy :: Ptr CGpiodEdgeEvent -> IO (Ptr CGpiodEdgeEvent)

-- | Raw C call to @gpiod_edge_event_get_event_type@. Gets event edge type (rising or falling).
foreign import ccall "gpiod_edge_event_get_event_type"
  c_gpiod_edge_event_get_event_type :: Ptr CGpiodEdgeEvent -> IO EdgeEventType

-- | Raw C call to @gpiod_edge_event_get_timestamp_ns@. Gets edge event timestamp in nanoseconds.
foreign import ccall "gpiod_edge_event_get_timestamp_ns" 
  c_gpiod_edge_event_get_timestamp_ns :: Ptr CGpiodEdgeEvent -> IO TimestampNs 

-- | Raw C call to @gpiod_edge_event_get_line_offset@. Gets line offset that generated edge event.
foreign import ccall "gpiod_edge_event_get_line_offset"
  c_gpiod_edge_event_get_line_offset :: Ptr CGpiodEdgeEvent -> IO LineOffset

-- | Raw C call to @gpiod_edge_event_get_global_seqno@. Gets global sequence number of edge event.
foreign import ccall "gpiod_edge_event_get_global_seqno"
  c_gpiod_edge_event_get_global_seqno :: Ptr CGpiodEdgeEvent -> IO CULong 

-- | Raw C call to @gpiod_edge_event_get_line_seqno@. Gets line-specific sequence number of edge event.
foreign import ccall "gpiod_edge_event_get_line_seqno"
  c_gpiod_edge_event_get_line_seqno :: Ptr CGpiodEdgeEvent -> IO LineOffset 

-- | Raw C call to @gpiod_edge_event_buffer_new@. Allocates edge event buffer with given capacity.
foreign import ccall "gpiod_edge_event_buffer_new"
  c_gpiod_edge_event_buffer_new :: EventBufferCapacity -> IO (Ptr CGpiodEdgeEventBuffer)

-- | Raw C call to @gpiod_edge_event_buffer_get_capacity@. Gets capacity of edge event buffer.
foreign import ccall "gpiod_edge_event_buffer_get_capacity"
  c_gpiod_edge_event_buffer_get_capacity :: Ptr CGpiodEdgeEventBuffer -> IO CSize

-- | Raw C call to @gpiod_edge_event_buffer_free@. Frees edge event buffer object.
foreign import ccall "gpiod_edge_event_buffer_free"
  c_gpiod_edge_event_buffer_free :: Ptr CGpiodEdgeEventBuffer -> IO ()

-- | Raw C call to @gpiod_edge_event_buffer_get_event@. Fetches event pointer from buffer by index.
foreign import ccall "gpiod_edge_event_buffer_get_event"
  c_gpiod_edge_event_buffer_get_event :: Ptr CGpiodEdgeEventBuffer -> BufferIndex -> IO (Ptr CGpiodEdgeEvent)

-- | Raw C call to @gpiod_edge_event_buffer_get_num_events@. Gets count of unread events stored in buffer.
foreign import ccall "gpiod_edge_event_buffer_get_num_events"
  c_gpiod_edge_event_buffer_get_num_events :: Ptr CGpiodEdgeEventBuffer -> IO CSize 

--------------------------------------------------------------------------------
-- 11. MISCELLANEOUS UTILITIES
--------------------------------------------------------------------------------

-- | Raw C call to @gpiod_is_gpiochip_device@. Checks if filesystem path refers to a GPIO chip dev node.
foreign import ccall "gpiod_is_gpiochip_device"
  c_gpiod_is_gpiochip_device :: CString -> IO CBool

-- | Raw C call to @gpiod_api_version@. Returns C library version string string (e.g. "2.1").
foreign import ccall "gpiod_api_version"
  c_gpiod_api_version :: IO CString
