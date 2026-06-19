-- Solo chat (si no ejecutaste la migracion 008 completa)
-- Supabase Dashboard → SQL Editor → pegar y Run

CREATE TABLE IF NOT EXISTS public.mensajes_solicitud (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  asesor_id uuid REFERENCES public.asesores_negocio(id),
  autor_tipo character varying NOT NULL
    CHECK (autor_tipo IN ('cliente', 'asesor')),
  contenido text NOT NULL CHECK (char_length(contenido) BETWEEN 1 AND 500),
  leido_cliente boolean NOT NULL DEFAULT false,
  leido_asesor boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mensajes_solicitud_solicitud_id
  ON public.mensajes_solicitud(solicitud_id, created_at);

ALTER TABLE public.mensajes_solicitud ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mensajes_select_participante ON public.mensajes_solicitud;
CREATE POLICY mensajes_select_participante ON public.mensajes_solicitud
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

DROP POLICY IF EXISTS mensajes_insert_cliente ON public.mensajes_solicitud;
CREATE POLICY mensajes_insert_cliente ON public.mensajes_solicitud
  FOR INSERT TO authenticated
  WITH CHECK (
    autor_tipo = 'cliente'
    AND cliente_id = public.cliente_id_actual()
    AND EXISTS (
      SELECT 1 FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND sc.cliente_id = public.cliente_id_actual()
    )
  );

DROP POLICY IF EXISTS mensajes_insert_asesor ON public.mensajes_solicitud;
CREATE POLICY mensajes_insert_asesor ON public.mensajes_solicitud
  FOR INSERT TO authenticated
  WITH CHECK (
    autor_tipo = 'asesor'
    AND public.es_asesor_activo()
    AND EXISTS (
      SELECT 1 FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND sc.asesor_id = public.current_asesor_id()
    )
  );

DROP POLICY IF EXISTS mensajes_update_cliente ON public.mensajes_solicitud;
CREATE POLICY mensajes_update_cliente ON public.mensajes_solicitud
  FOR UPDATE TO authenticated
  USING (cliente_id = public.cliente_id_actual())
  WITH CHECK (cliente_id = public.cliente_id_actual());

DROP POLICY IF EXISTS mensajes_update_asesor ON public.mensajes_solicitud;
CREATE POLICY mensajes_update_asesor ON public.mensajes_solicitud
  FOR UPDATE TO authenticated
  USING (public.es_asesor_activo())
  WITH CHECK (public.es_asesor_activo());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'mensajes_solicitud'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.mensajes_solicitud;
  END IF;
END $$;
