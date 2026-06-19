-- Realtime para creditos y solicitudes (app clientes)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'creditos'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.creditos;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'solicitudes_credito'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.solicitudes_credito;
  END IF;
END $$;
