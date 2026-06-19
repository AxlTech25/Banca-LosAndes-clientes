-- Flujo de estados para solicitudes originadas en app clientes (acciones del asesor)

CREATE OR REPLACE FUNCTION public.actualizar_estado_solicitud_app_cliente(
  p_solicitud_id uuid,
  p_nuevo_estado text,
  p_motivo_rechazo text DEFAULT NULL,
  p_monto_aprobado numeric DEFAULT NULL,
  p_condicion_adicional text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden cambiar el estado.';
  END IF;

  SELECT * INTO v_solicitud
  FROM public.solicitudes_credito
  WHERE id = p_solicitud_id
    AND origen = 'app_cliente'
    AND asesor_id = public.current_asesor_id();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada o no asignada a usted.';
  END IF;

  IF NOT (
    (v_solicitud.estado = 'pendiente' AND p_nuevo_estado = 'en_evaluacion')
    OR (v_solicitud.estado = 'en_evaluacion' AND p_nuevo_estado IN ('observada', 'aprobada', 'rechazada'))
    OR (v_solicitud.estado = 'observada' AND p_nuevo_estado = 'en_evaluacion')
    OR (v_solicitud.estado = 'aprobada' AND p_nuevo_estado = 'desembolsada')
  ) THEN
    RAISE EXCEPTION 'Transicion de % a % no permitida.', v_solicitud.estado, p_nuevo_estado;
  END IF;

  IF p_nuevo_estado = 'rechazada'
     AND (p_motivo_rechazo IS NULL OR btrim(p_motivo_rechazo) = '') THEN
    RAISE EXCEPTION 'Debe indicar el motivo de rechazo.';
  END IF;

  IF p_nuevo_estado = 'aprobada'
     AND (p_monto_aprobado IS NULL OR p_monto_aprobado <= 0) THEN
    RAISE EXCEPTION 'Debe indicar el monto aprobado.';
  END IF;

  UPDATE public.solicitudes_credito
  SET
    estado = p_nuevo_estado,
    motivo_rechazo = CASE
      WHEN p_nuevo_estado = 'rechazada' THEN btrim(p_motivo_rechazo)
      ELSE motivo_rechazo
    END,
    monto_aprobado = CASE
      WHEN p_nuevo_estado = 'aprobada' THEN p_monto_aprobado
      ELSE monto_aprobado
    END,
    condicion_adicional = CASE
      WHEN p_condicion_adicional IS NOT NULL AND btrim(p_condicion_adicional) <> ''
        THEN btrim(p_condicion_adicional)
      ELSE condicion_adicional
    END,
    updated_at = now()
  WHERE id = p_solicitud_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.actualizar_estado_solicitud_app_cliente(uuid, text, text, numeric, text)
  TO authenticated;
