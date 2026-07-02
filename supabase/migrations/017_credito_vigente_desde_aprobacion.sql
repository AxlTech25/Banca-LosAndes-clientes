-- Crear credito vigente al aprobar/desembolsar solicitud app_cliente (pagos desde app)

ALTER TABLE public.creditos
  ADD COLUMN IF NOT EXISTS solicitud_id uuid REFERENCES public.solicitudes_credito (id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_creditos_solicitud_id
  ON public.creditos (solicitud_id)
  WHERE solicitud_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.crear_credito_desde_solicitud(p_solicitud_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
  v_credito_id uuid;
  v_monto numeric;
  v_plazo integer;
  v_fecha_vencimiento date;
BEGIN
  SELECT * INTO v_solicitud
  FROM public.solicitudes_credito
  WHERE id = p_solicitud_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada.';
  END IF;

  IF v_solicitud.estado NOT IN ('aprobada', 'desembolsada') THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_credito_id
  FROM public.creditos
  WHERE solicitud_id = p_solicitud_id
  LIMIT 1;

  IF v_credito_id IS NOT NULL THEN
    RETURN v_credito_id;
  END IF;

  v_monto := coalesce(v_solicitud.monto_aprobado, v_solicitud.monto_solicitado);
  v_plazo := coalesce(v_solicitud.plazo_meses, 0);

  IF v_monto <= 0 OR v_plazo <= 0 THEN
    RAISE EXCEPTION 'La solicitud no tiene monto o plazo valido.';
  END IF;

  SELECT fecha_pago INTO v_fecha_vencimiento
  FROM public.solicitudes_cronograma_cuotas
  WHERE solicitud_id = p_solicitud_id
    AND numero_cuota = 1
  LIMIT 1;

  IF v_fecha_vencimiento IS NULL THEN
    v_fecha_vencimiento := coalesce(
      v_solicitud.fecha_desembolso_programada,
      current_date + interval '1 month'
    )::date;
  END IF;

  INSERT INTO public.creditos (
    cliente_id,
    solicitud_id,
    producto,
    saldo_actual,
    monto_desembolsado,
    cuotas_total,
    cuotas_pagadas,
    dias_mora,
    estado,
    fecha_vencimiento,
    tea,
    plazo_meses
  )
  VALUES (
    v_solicitud.cliente_id,
    p_solicitud_id,
    coalesce(v_solicitud.producto, 'credito_empresarial_micro'),
    v_monto,
    v_monto,
    v_plazo,
    0,
    0,
    'vigente',
    v_fecha_vencimiento,
    coalesce(v_solicitud.tea_referencial, 43.92),
    v_plazo
  )
  RETURNING id INTO v_credito_id;

  RETURN v_credito_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.crear_credito_desde_solicitud(uuid) TO authenticated;

-- Extiende aprobacion: cronograma + credito vigente para pagos del cliente
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
  v_visita_ok boolean;
  v_pre_eval_ok boolean;
  v_buro_ok boolean;
  v_perfil text := coalesce(public.current_asesor_perfil(), '');
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden cambiar el estado.';
  END IF;

  IF p_nuevo_estado = 'aprobada' THEN
    IF v_perfil <> 'super_operador' THEN
      RAISE EXCEPTION 'Solo el super operador puede aprobar solicitudes.';
    END IF;

    SELECT * INTO v_solicitud
    FROM public.solicitudes_credito
    WHERE id = p_solicitud_id
      AND origen = 'app_cliente'
      AND agencia_id = public.current_agencia_id();
  ELSE
    SELECT * INTO v_solicitud
    FROM public.solicitudes_credito
    WHERE id = p_solicitud_id
      AND origen = 'app_cliente'
      AND asesor_id = public.current_asesor_id();
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada o sin permisos para esta accion.';
  END IF;

  IF NOT (
    (v_solicitud.estado = 'pendiente' AND p_nuevo_estado = 'en_evaluacion')
    OR (v_solicitud.estado = 'en_evaluacion' AND p_nuevo_estado IN ('observada', 'aprobada', 'rechazada'))
    OR (v_solicitud.estado = 'observada' AND p_nuevo_estado = 'en_evaluacion')
    OR (v_solicitud.estado = 'aprobada' AND p_nuevo_estado = 'desembolsada')
  ) THEN
    RAISE EXCEPTION 'Transicion de % a % no permitida.', v_solicitud.estado, p_nuevo_estado;
  END IF;

  IF p_nuevo_estado = 'aprobada' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cartera_diaria cd
      WHERE cd.id = v_solicitud.cartera_diaria_id
        AND cd.estado_visita = 'visitado'
    ) OR EXISTS (
      SELECT 1
      FROM public.cartera_diaria cd
      WHERE cd.solicitud_id = p_solicitud_id
        AND cd.estado_visita = 'visitado'
    )
    INTO v_visita_ok;

    IF NOT v_visita_ok THEN
      RAISE EXCEPTION 'Debe registrar la visita en campo antes de aprobar.';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM public.pre_evaluaciones_solicitud pe
      WHERE pe.solicitud_id = p_solicitud_id
        AND upper(pe.calificacion) = 'APTO'
    )
    INTO v_pre_eval_ok;

    IF NOT v_pre_eval_ok THEN
      RAISE EXCEPTION 'Debe completar la pre-evaluacion con resultado APTO antes de aprobar.';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM public.consultas_buro cb
      WHERE cb.solicitud_id = p_solicitud_id
    )
    INTO v_buro_ok;

    IF NOT v_buro_ok THEN
      RAISE EXCEPTION 'Debe registrar la consulta de buro antes de aprobar.';
    END IF;
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

  IF p_nuevo_estado = 'aprobada' THEN
    PERFORM public.generar_cronograma_solicitud_aprobada(p_solicitud_id, NULL);
    PERFORM public.crear_credito_desde_solicitud(p_solicitud_id);
  ELSIF p_nuevo_estado = 'desembolsada' THEN
    PERFORM public.crear_credito_desde_solicitud(p_solicitud_id);
  END IF;
END;
$$;

-- Creditos vigentes para solicitudes ya aprobadas antes de esta migracion
DO $$
DECLARE
  v_solicitud record;
BEGIN
  FOR v_solicitud IN
    SELECT id
    FROM public.solicitudes_credito
    WHERE estado IN ('aprobada', 'desembolsada')
  LOOP
    BEGIN
      PERFORM public.crear_credito_desde_solicitud(v_solicitud.id);
    EXCEPTION
      WHEN others THEN
        NULL;
    END;
  END LOOP;
END;
$$;
