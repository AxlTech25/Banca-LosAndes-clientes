-- Permite subir documentos en solicitudes app_cliente en estado pendiente
-- (las nuevas solicitudes se crean directamente como pendiente)

DROP POLICY IF EXISTS solicitud_docs_insert_cliente ON public.solicitudes_documentos;
CREATE POLICY solicitud_docs_insert_cliente ON public.solicitudes_documentos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND sc.cliente_id = public.cliente_id_actual()
        AND sc.estado IN ('borrador', 'pendiente', 'observada')
    )
  );
