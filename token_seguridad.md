¡Con mucho gusto! Aquí tienes la implementación completa del patrón de Token de Seguridad (ReadyRequest) para guardar de referencia e implementar
  posteriormente en fuyu-gpio-simple.
  ──────
  ### 🛡️ Implementación del Token de Seguridad (ReadyRequest)

  #### 1. Tipo del Token y WaitResult

    -- | Token opaco que garantiza que se ha llamado a `waitEdgeEvents` 
    -- y que hay eventos pendientes listos para leer en el buffer.
    newtype ReadyRequest = ReadyRequest LineRequest
      deriving (Eq, Show)
    
    -- | Desenvolver el token para obtener el LineRequest original.
    readyToLineRequest :: ReadyRequest -> LineRequest
    readyToLineRequest (ReadyRequest req) = req

    -- | Resultado de espera que contiene el Token si hay eventos listos.
    data WaitResult
      = Timeout
      | EventsReady ReadyRequest
      deriving (Eq, Show)

  #### 2. Producción del Token (waitEdgeEvents)

    -- | Espera eventos de borde. Si hay eventos disponibles (retorno 1 de C),
    -- envuelve el `LineRequest` dentro del token `ReadyRequest`.
    waitEdgeEvents :: LineRequest -> TimeoutNs -> IO (Either Errno WaitResult)
    waitEdgeEvents req timeoutNs = do
      res <- c_gpiod_line_request_wait_edge_events (toCPtr req) (timeoutNsToC timeoutNs)
      if res == -1
        then Left <$> getErrno
        else case res of
          1 -> return $ Right (EventsReady (ReadyRequest req))
          0 -> return $ Right Timeout
          _ -> return $ Right Timeout

  #### 3. Consumo Obligatorio del Token (readEdgeEvents)

    -- | La firma exige `ReadyRequest`. Es imposible llamar a esta función 
    -- a menos que el usuario haya obtenido previamente el token `EventsReady`.
    readEdgeEvents :: ReadyRequest -> EventBuffer -> IO (Either Errno (NonEmpty EdgeEvent))
    readEdgeEvents readyReq buf = do
      let req = readyToLineRequest readyReq
      eCount <- readEventsIntoBuffer req buf
      case eCount of
        Left err -> return (Left err)
        Right count -> do
          events <- forM [0 .. (count - 1)] $ \idx -> do
            eRaw <- getRawEventFromBuffer buf (BufferIndex (fromIntegral idx))
            case eRaw of
              Left _ -> error "readEdgeEvents: índice fuera de rango"
              Right raw -> rawToEdgeEvent raw
          case NE.nonEmpty events of
            Just ne -> return (Right ne)
            Nothing -> return (Left eINVAL)
    ──────
  ### 💡 Idea Avanzada para fuyu-gpio-simple: Phantom Types (Type-Safe State Machine)

  Para fuyu-gpio-simple, también puedes llevar este token un paso más allá usando Phantom Types (Tipos Fantasma) para representar la máquina de estados
  en tiempo de compilación:

    -- Estados de la línea
    data Idle
    data Ready

    -- El parámetro 'status' no existe en tiempo de ejecución (cero costo)
    newtype LineRequest status = LineRequest (Ptr CGpiodLineRequest)

    -- Esperar eventos cambia el estado de Idle a Ready en el tipo
    waitEdgeEvents :: LineRequest Idle -> TimeoutNs -> IO (Either Errno (WaitResult status))

    -- Leer solo acepta un LineRequest en estado Ready
    readEdgeEvents :: LineRequest Ready -> EventBuffer -> IO (Either Errno (NonEmpty EdgeEvent))

  De esta forma, ¡el propio compilador de Haskell impide intentar leer una línea si no está en estado Ready!
