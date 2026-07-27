{-# LANGUAGE ForeignFunctionInterface #-}
module Fuyu.GPIO.Direct.Bindings where

import Foreign.C.String (CString)
import Foreign.C.Types (CInt(..), CLong(..), CSize(..), CUInt(..), CULong(..), CBool(..))
import Foreign.Ptr (Ptr)
import Fuyu.GPIO.Direct.Types
import Data.Int (Int64)

--------------------------------------------------------------------------------
-- 1. CHIP MANAGEMENT
--------------------------------------------------------------------------------

foreign import ccall "gpiod_chip_open"
  c_gpiod_chip_open :: CString -> IO (Ptr CGpiodChip)
    
foreign import ccall "gpiod_chip_close"
  c_gpiod_chip_close :: Ptr CGpiodChip -> IO ()

foreign import ccall "gpiod_chip_get_info"
  c_gpiod_chip_get_info :: Ptr CGpiodChip -> IO (Ptr CGpiodChipInfo) 

foreign import ccall "gpiod_chip_get_path"
  c_gpiod_chip_get_path :: Ptr CGpiodChip -> IO CString  

foreign import ccall "gpiod_chip_get_line_info"
  c_gpiod_chip_get_line_info :: Ptr CGpiodChip -> LineOffset -> IO (Ptr CGpiodLineInfo) 

foreign import ccall "gpiod_chip_watch_line_info"
  c_gpiod_chip_watch_line_info :: Ptr CGpiodChip -> LineOffset -> IO (Ptr CGpiodLineInfo) 

foreign import ccall "gpiod_chip_unwatch_line_info"
  c_gpiod_chip_unwatch_line_info :: Ptr CGpiodChip -> LineOffset -> IO CInt

foreign import ccall "gpiod_chip_get_fd"
  c_gpiod_chip_get_fd :: Ptr CGpiodChip -> IO CInt 

foreign import ccall "gpiod_chip_wait_info_event"
  c_gpiod_chip_wait_info_event :: Ptr CGpiodChip -> Int64 -> IO CInt 

foreign import ccall "gpiod_chip_read_info_event"
  c_gpiod_chip_read_info_event :: Ptr CGpiodChip -> IO (Ptr CGpiodInfoEvent)

foreign import ccall "gpiod_chip_request_lines"
  c_gpiod_chip_request_lines :: Ptr CGpiodChip 
                             -> Ptr CGpiodRequestConfig
                             -> Ptr CGpiodLineConfig
                             -> IO (Ptr CGpiodLineRequest)

foreign import ccall "gpiod_chip_get_line_offset_from_name"
  c_gpiod_chip_get_line_offset_from_name :: Ptr CGpiodChip -> CString -> IO CInt
  
--------------------------------------------------------------------------------
-- 2. CHIP INFO
--------------------------------------------------------------------------------

foreign import ccall "gpiod_chip_info_free"
  c_gpiod_chip_info_free :: Ptr CGpiodChipInfo -> IO ()
  
foreign import ccall "gpiod_chip_info_get_name"
  c_gpiod_chip_info_get_name :: Ptr CGpiodChipInfo -> IO CString
  
foreign import ccall "gpiod_chip_info_get_label"
  c_gpiod_chip_info_get_label :: Ptr CGpiodChipInfo -> IO CString  

foreign import ccall "gpiod_chip_info_get_num_lines"
  c_gpiod_chip_info_get_num_lines :: Ptr CGpiodChipInfo -> IO CSize 

--------------------------------------------------------------------------------
-- 4. LINE INFORMATION
--------------------------------------------------------------------------------

foreign import ccall "gpiod_line_info_free"
  c_gpiod_line_info_free :: Ptr CGpiodLineInfo -> IO ()

foreign import ccall "gpiod_line_info_copy"
  c_gpiod_line_info_copy :: Ptr CGpiodLineInfo -> IO (Ptr CGpiodLineInfo)

foreign import ccall "gpiod_line_info_get_offset"
  c_gpiod_line_info_get_offset :: Ptr CGpiodLineInfo -> IO LineOffset

foreign import ccall "gpiod_line_info_get_name"
  c_gpiod_line_info_get_name :: Ptr CGpiodLineInfo -> IO CString

foreign import ccall "gpiod_line_info_is_used"
  c_gpiod_line_info_is_used :: Ptr CGpiodLineInfo -> IO CBool

foreign import ccall "gpiod_line_info_get_consumer"
  c_gpiod_line_info_get_consumer :: Ptr CGpiodLineInfo -> IO CString
     
foreign import ccall "gpiod_line_info_get_direction"
  c_gpiod_line_info_get_direction :: Ptr CGpiodLineInfo -> IO LineDirection

foreign import ccall "gpiod_line_info_get_edge_detection"
  c_gpiod_line_info_get_edge_detection :: Ptr CGpiodLineInfo -> IO LineEdge

foreign import ccall "gpiod_line_info_get_bias"
  c_gpiod_line_info_get_bias :: Ptr CGpiodLineInfo -> IO LineBias

foreign import ccall "gpiod_line_info_get_drive"
  c_gpiod_line_info_get_drive :: Ptr CGpiodLineInfo -> IO LineDrive

foreign import ccall "gpiod_line_info_is_active_low"
  c_gpiod_line_info_is_active_low :: Ptr CGpiodLineInfo -> IO CBool  

foreign import ccall "gpiod_line_info_is_debounced"
  c_gpiod_line_info_is_debounced :: Ptr CGpiodLineInfo -> IO CBool  

foreign import ccall "gpiod_line_info_get_debounce_period_us"
  c_gpiod_line_info_get_debounce_period_us :: Ptr CGpiodLineInfo -> IO CULong

foreign import ccall "gpiod_line_info_get_event_clock"
  c_gpiod_line_info_get_event_clock :: Ptr CGpiodLineInfo -> IO LineClock

--------------------------------------------------------------------------------
-- 5. LINE WATCH (INFO EVENT)
--------------------------------------------------------------------------------
foreign import ccall "gpiod_info_event_free"
  c_gpiod_info_event_free :: Ptr CGpiodInfoEvent -> IO ()
  
foreign import ccall "gpiod_info_event_get_event_type"
  c_gpiod_info_event_get_event_type :: Ptr CGpiodInfoEvent -> IO InfoEventType
  
foreign import ccall "gpiod_info_event_get_timestamp_ns"
  c_gpiod_info_event_get_timestamp_ns :: Ptr CGpiodInfoEvent -> IO TimestampNs
  
foreign import ccall "gpiod_info_event_get_line_info"
  c_gpiod_info_event_get_line_info :: Ptr CGpiodInfoEvent -> IO (Ptr CGpiodLineInfo)
  
--------------------------------------------------------------------------------
-- 6. LINE SETTINGS
--------------------------------------------------------------------------------

foreign import ccall "gpiod_line_settings_new"
  c_gpiod_line_settings_new :: IO (Ptr CGpiodLineSettings)

foreign import ccall "gpiod_line_settings_free"
  c_gpiod_line_settings_free :: Ptr CGpiodLineSettings -> IO ()
    
foreign import ccall "gpiod_line_settings_reset"
  c_gpiod_line_settings_reset :: Ptr CGpiodLineSettings -> IO ()
    
foreign import ccall "gpiod_line_settings_copy"
  c_gpiod_line_settings_copy :: Ptr CGpiodLineSettings -> IO (Ptr CGpiodLineSettings)

foreign import ccall "gpiod_line_settings_set_direction"
  c_gpiod_line_settings_set_direction :: Ptr CGpiodLineSettings -> LineDirection -> IO CInt      
      
foreign import ccall "gpiod_line_settings_get_direction"
  c_gpiod_line_settings_get_direction :: Ptr CGpiodLineSettings -> IO LineDirection

foreign import ccall "gpiod_line_settings_set_edge_detection"
  c_gpiod_line_settings_set_edge_detection :: Ptr CGpiodLineSettings -> LineEdge -> IO CInt 
  
foreign import ccall "gpiod_line_settings_get_edge_detection"
  c_gpiod_line_settings_get_edge_detection :: Ptr CGpiodLineSettings -> IO LineEdge 

foreign import ccall "gpiod_line_settings_set_bias"
  c_gpiod_line_settings_set_bias :: Ptr CGpiodLineSettings -> LineBias -> IO CInt
  
foreign import ccall "gpiod_line_settings_get_bias"
  c_gpiod_line_settings_get_bias :: Ptr CGpiodLineSettings -> IO LineBias

foreign import ccall "gpiod_line_settings_set_drive"
  c_gpiod_line_settings_set_drive :: Ptr CGpiodLineSettings -> LineDrive -> IO CInt

foreign import ccall "gpiod_line_settings_get_drive"
  c_gpiod_line_settings_get_drive :: Ptr CGpiodLineSettings -> IO LineDrive

foreign import ccall "gpiod_line_settings_set_active_low"
  c_gpiod_line_settings_set_active_low :: Ptr CGpiodLineSettings -> CBool -> IO ()  

foreign import ccall "gpiod_line_settings_get_active_low"
  c_gpiod_line_settings_get_active_low :: Ptr CGpiodLineSettings -> IO CBool

foreign import ccall "gpiod_line_settings_set_debounce_period_us"
  c_gpiod_line_settings_set_debounce_period_us :: Ptr CGpiodLineSettings -> CLong -> IO ()  

foreign import ccall "gpiod_line_settings_get_debounce_period_us"
  c_gpiod_line_settings_get_debounce_period_us :: Ptr CGpiodLineSettings -> IO CLong

foreign import ccall "gpiod_line_settings_set_event_clock"
  c_gpiod_line_settings_set_event_clock :: Ptr CGpiodLineSettings -> LineClock -> IO CInt 

foreign import ccall "gpiod_line_settings_get_event_clock"
  c_gpiod_line_settings_get_event_clock :: Ptr CGpiodLineSettings -> IO LineClock

foreign import ccall "gpiod_line_settings_set_output_value"
  c_gpiod_line_settings_set_output_value :: Ptr CGpiodLineSettings -> LineValue -> IO CInt 

foreign import ccall "gpiod_line_settings_get_output_value"
  c_gpiod_line_settings_get_output_value :: Ptr CGpiodLineSettings -> IO LineValue


--------------------------------------------------------------------------------
-- 7. LINE CONFIGURATION
--------------------------------------------------------------------------------

foreign import ccall "gpiod_line_config_new"
  c_gpiod_line_config_new :: IO (Ptr CGpiodLineConfig)

foreign import ccall "gpiod_line_config_free"
  c_gpiod_line_config_free :: Ptr CGpiodLineConfig -> IO ()

foreign import ccall "gpiod_line_config_reset"
  c_gpiod_line_config_reset :: Ptr CGpiodLineConfig -> IO ()

foreign import ccall "gpiod_line_config_add_line_settings"
  c_gpiod_line_config_add_line_settings :: Ptr CGpiodLineConfig
                                        -> Ptr LineOffset
                                        -> CSize
                                        -> Ptr CGpiodLineSettings 
                                        -> IO CInt
                                        
foreign import ccall "gpiod_line_config_get_line_settings"
  c_gpiod_line_config_get_line_settings :: Ptr CGpiodLineConfig -> LineOffset -> IO (Ptr CGpiodLineSettings)

foreign import ccall "gpiod_line_config_set_output_values"
  c_gpiod_line_config_set_output_values :: Ptr CGpiodLineConfig -> Ptr LineValue -> CSize -> IO CInt

foreign import ccall "gpiod_line_config_get_num_configured_offsets"
  c_gpiod_line_config_get_num_configured_offsets :: Ptr CGpiodLineConfig -> IO CSize

foreign import ccall "gpiod_line_config_get_configured_offsets"
  c_gpiod_line_config_get_configured_offsets :: Ptr CGpiodLineConfig -> Ptr LineOffset -> CSize -> IO CSize

--------------------------------------------------------------------------------
-- 8. REQUESTS CONFIG
--------------------------------------------------------------------------------
foreign import ccall "gpiod_request_config_new"
  c_gpiod_request_config_new :: IO (Ptr CGpiodRequestConfig)

foreign import ccall "gpiod_request_config_free"
  c_gpiod_request_config_free :: Ptr CGpiodRequestConfig -> IO()

foreign import ccall "gpiod_request_config_set_consumer"
  c_gpiod_request_config_set_consumer :: Ptr CGpiodRequestConfig -> CString -> IO()

foreign import ccall "gpiod_request_config_get_consumer"
  c_gpiod_request_config_get_consumer :: Ptr CGpiodRequestConfig -> IO CString

foreign import ccall "gpiod_request_config_set_event_buffer_size"
  c_gpiod_request_config_set_event_buffer_size :: Ptr CGpiodRequestConfig -> CSize -> IO()   
  
foreign import ccall "gpiod_request_config_get_event_buffer_size"
  c_gpiod_request_config_get_event_buffer_size :: Ptr CGpiodRequestConfig -> IO CSize  
  
--------------------------------------------------------------------------------
-- 9. LINE REQUEST
--------------------------------------------------------------------------------
foreign import ccall "gpiod_line_request_release"
  c_gpiod_line_request_release :: Ptr CGpiodLineRequest -> IO()

foreign import ccall "gpiod_line_request_get_chip_name"
  c_gpiod_line_request_get_chip_name :: Ptr CGpiodLineRequest -> IO CString

foreign import ccall "gpiod_line_request_get_num_requested_lines"
  c_gpiod_line_request_get_num_requested_lines :: Ptr CGpiodLineRequest -> IO CSize
     
foreign import ccall "gpiod_line_request_get_requested_offsets"
  c_gpiod_line_request_get_requested_offsets :: Ptr CGpiodLineRequest -> Ptr LineOffset -> CSize -> IO CSize
  
foreign import ccall "gpiod_line_request_get_value"
  c_gpiod_line_request_get_value :: Ptr CGpiodLineRequest -> LineOffset -> IO LineValue 

foreign import ccall "gpiod_line_request_get_values_subset"
  c_gpiod_line_request_get_values_subset :: Ptr CGpiodLineRequest
                                         -> CSize
                                         -> Ptr CUInt
                                         -> Ptr CInt
                                         -> IO CInt

foreign import ccall "gpiod_line_request_set_value"
  c_gpiod_line_request_set_value :: Ptr CGpiodLineRequest -> LineOffset -> LineValue -> IO CInt 

foreign import ccall "gpiod_line_request_wait_edge_events"
  c_gpiod_line_request_wait_edge_events :: Ptr CGpiodLineRequest -> CLong -> IO CInt

foreign import ccall "gpiod_line_request_read_edge_events" 
  c_gpiod_line_request_read_edge_events :: Ptr CGpiodLineRequest -> Ptr CGpiodEdgeEventBuffer -> CSize -> IO CInt

--------------------------------------------------------------------------------
-- 10. EDGE EVENTS & EVENT BUFFER
--------------------------------------------------------------------------------

foreign import ccall "gpiod_edge_event_buffer_new"
  c_gpiod_edge_event_buffer_new :: EventBufferCapacity -> IO (Ptr CGpiodEdgeEventBuffer)
  
foreign import ccall "gpiod_edge_event_buffer_free"
  c_gpiod_edge_event_buffer_free :: Ptr CGpiodEdgeEventBuffer -> IO ()

foreign import ccall "gpiod_edge_event_get_event_type"
  c_gpiod_edge_event_get_event_type :: Ptr CGpiodEdgeEvent -> IO EdgeEventType

foreign import ccall "gpiod_edge_event_buffer_get_event"
  c_gpiod_edge_event_buffer_get_event :: Ptr CGpiodEdgeEventBuffer -> BufferIndex -> IO (Ptr CGpiodEdgeEvent)

foreign import ccall "gpiod_edge_event_get_timestamp_ns" 
  c_gpiod_edge_event_get_timestamp_ns :: Ptr CGpiodEdgeEvent -> IO TimestampNs 

foreign import ccall "gpiod_edge_event_get_line_offset"
  c_gpiod_edge_event_get_line_offset :: Ptr CGpiodEdgeEvent -> IO LineOffset
