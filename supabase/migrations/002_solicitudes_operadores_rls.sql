-- Permite a asesores ver solicitudes iniciadas desde app clientes sin asesor asignado
DROP POLICY IF EXISTS asesor_solicitudes_pendientes_cliente ON public.solicitudes_credito;
CREATE POLICY asesor_solicitudes_pendientes_cliente
  ON public.solicitudes_credito
  FOR SELECT
  TO authenticated
  USING (
    public.es_asesor_activo()
    AND origen = 'app_cliente'
    AND asesor_id IS NULL
    AND estado IN ('pendiente', 'borrador')
  );

-- Permite asignarse una solicitud pendiente (tomar caso)
DROP POLICY IF EXISTS asesor_solicitudes_asignar ON public.solicitudes_credito;
CREATE POLICY asesor_solicitudes_asignar
  ON public.solicitudes_credito
  FOR UPDATE
  TO authenticated
  USING (
    public.es_asesor_activo()
    AND origen = 'app_cliente'
    AND asesor_id IS NULL
    AND estado = 'pendiente'
  )
  WITH CHECK (
    asesor_id = public.current_asesor_id()
    AND agencia_id = public.current_agencia_id()
  );
