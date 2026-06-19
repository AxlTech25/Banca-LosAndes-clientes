-- Documentos de solicitud: acceso Storage para app clientes
-- Bucket existente: documentos-solicitudes (carpeta = solicitud_id)

DROP POLICY IF EXISTS cliente_documentos_storage_select ON storage.objects;
CREATE POLICY cliente_documentos_storage_select
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'documentos-solicitudes'
    AND (storage.foldername(name))[1] IN (
      SELECT sc.id::text
      FROM public.solicitudes_credito sc
      WHERE sc.cliente_id = public.cliente_id_actual()
    )
  );

DROP POLICY IF EXISTS cliente_documentos_storage_insert ON storage.objects;
CREATE POLICY cliente_documentos_storage_insert
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'documentos-solicitudes'
    AND (storage.foldername(name))[1] IN (
      SELECT sc.id::text
      FROM public.solicitudes_credito sc
      WHERE sc.cliente_id = public.cliente_id_actual()
        AND sc.estado IN ('borrador', 'pendiente', 'observada')
    )
  );

-- Asesor: ver documentos de solicitudes app_cliente pendientes (sin asignar aun)
DROP POLICY IF EXISTS asesor_documentos_storage_select_pendientes ON storage.objects;
CREATE POLICY asesor_documentos_storage_select_pendientes
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'documentos-solicitudes'
    AND public.es_asesor_activo()
    AND (storage.foldername(name))[1] IN (
      SELECT sc.id::text
      FROM public.solicitudes_credito sc
      WHERE sc.origen = 'app_cliente'
        AND sc.estado IN ('pendiente', 'en_evaluacion', 'observada', 'aprobada')
    )
  );
