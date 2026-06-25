-- Flujo asesor app_cliente: cartera al tomar caso, visita, pre-eval, buró por DNI,
-- aprobación solo super_operador con checklist obligatorio.

ALTER TABLE public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS cartera_diaria_id uuid REFERENCES public.cartera_diaria (id);

ALTER TABLE public.cartera_diaria
  ADD COLUMN IF NOT EXISTS solicitud_id uuid REFERENCES public.solicitudes_credito (id);

CREATE TABLE IF NOT EXISTS public.pre_evaluaciones_solicitud (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL UNIQUE REFERENCES public.solicitudes_credito (id) ON DELETE CASCADE,
  asesor_id uuid NOT NULL REFERENCES public.asesores_negocio (id),
  calificacion varchar(20) NOT NULL,
  puntaje integer CHECK (puntaje BETWEEN 0 AND 100),
  motivo text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pre_eval_solicitud
  ON public.pre_evaluaciones_solicitud (solicitud_id);

ALTER TABLE public.pre_evaluaciones_solicitud ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS asesor_pre_eval_select ON public.pre_evaluaciones_solicitud;
CREATE POLICY asesor_pre_eval_select
  ON public.pre_evaluaciones_solicitud
  FOR SELECT
  TO authenticated
  USING (
    public.es_asesor_activo()
    AND EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      WHERE sc.id = pre_evaluaciones_solicitud.solicitud_id
        AND sc.asesor_id = public.current_asesor_id()
    )
  );

DROP POLICY IF EXISTS asesor_pre_eval_insert ON public.pre_evaluaciones_solicitud;
CREATE POLICY asesor_pre_eval_insert
  ON public.pre_evaluaciones_solicitud
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.es_asesor_activo()
    AND asesor_id = public.current_asesor_id()
    AND EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      WHERE sc.id = pre_evaluaciones_solicitud.solicitud_id
        AND sc.asesor_id = public.current_asesor_id()
        AND sc.origen = 'app_cliente'
    )
  );

-- Buró simulado determinista por último dígito del DNI (curso / Caso 1: ...0 → Normal S/4,500)
CREATE OR REPLACE FUNCTION public.consultar_buro_simulado_por_dni(p_dni text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_digit integer;
BEGIN
  p_dni := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  IF length(p_dni) < 1 THEN
    RETURN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1200,
      'mayor_deuda', 1200,
      'dias_mayor_mora', 0
    );
  END IF;

  v_digit := (right(p_dni, 1))::integer;

  RETURN CASE v_digit
    WHEN 0 THEN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 4500,
      'mayor_deuda', 4500,
      'dias_mayor_mora', 0
    )
    WHEN 1 THEN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 2,
      'deuda_total_pen', 3200,
      'mayor_deuda', 2000,
      'dias_mayor_mora', 0
    )
    WHEN 2 THEN jsonb_build_object(
      'calificacion_sbs', 'CPP',
      'entidades_con_deuda', 2,
      'deuda_total_pen', 4800,
      'mayor_deuda', 3200,
      'dias_mayor_mora', 12
    )
    WHEN 3 THEN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 2800,
      'mayor_deuda', 2800,
      'dias_mayor_mora', 0
    )
    WHEN 4 THEN jsonb_build_object(
      'calificacion_sbs', 'Deficiente',
      'entidades_con_deuda', 3,
      'deuda_total_pen', 9200,
      'mayor_deuda', 5100,
      'dias_mayor_mora', 45
    )
    WHEN 5 THEN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 0,
      'deuda_total_pen', 0,
      'mayor_deuda', 0,
      'dias_mayor_mora', 0
    )
    WHEN 6 THEN jsonb_build_object(
      'calificacion_sbs', 'CPP',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1500,
      'mayor_deuda', 1500,
      'dias_mayor_mora', 5
    )
    WHEN 7 THEN jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1200,
      'mayor_deuda', 1200,
      'dias_mayor_mora', 0
    )
    WHEN 8 THEN jsonb_build_object(
      'calificacion_sbs', 'Dudoso',
      'entidades_con_deuda', 4,
      'deuda_total_pen', 15000,
      'mayor_deuda', 8000,
      'dias_mayor_mora', 90
    )
    ELSE jsonb_build_object(
      'calificacion_sbs', 'Perdida',
      'entidades_con_deuda', 5,
      'deuda_total_pen', 22000,
      'mayor_deuda', 12000,
      'dias_mayor_mora', 180
    )
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.consultar_buro_simulado_por_dni(text) TO authenticated;

-- Pre-evaluación desde datos de la solicitud app_cliente
CREATE OR REPLACE FUNCTION public.pre_evaluar_solicitud_app_cliente(p_solicitud_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
  v_ratio numeric;
  v_calificacion text;
  v_puntaje integer;
  v_motivo text;
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden pre-evaluar.';
  END IF;

  SELECT sc.*, c.calificacion_sbs
  INTO v_solicitud
  FROM public.solicitudes_credito sc
  JOIN public.clientes c ON c.id = sc.cliente_id
  WHERE sc.id = p_solicitud_id
    AND sc.origen = 'app_cliente'
    AND sc.asesor_id = public.current_asesor_id();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada o no asignada a usted.';
  END IF;

  IF coalesce(v_solicitud.antiguedad_negocio_meses, 0) < 6 THEN
    v_calificacion := 'NO PROCEDE';
    v_puntaje := 15;
    v_motivo := 'El negocio debe tener al menos 6 meses de antiguedad.';
  ELSIF coalesce(v_solicitud.ingresos_estimados, 0) <= 0 THEN
    v_calificacion := 'NO PROCEDE';
    v_puntaje := 20;
    v_motivo := 'Ingresos estimados insuficientes para evaluar.';
  ELSE
    v_ratio := v_solicitud.monto_solicitado / v_solicitud.ingresos_estimados;

    IF lower(coalesce(v_solicitud.calificacion_sbs, '')) LIKE '%dudoso%'
       OR lower(coalesce(v_solicitud.calificacion_sbs, '')) LIKE '%perdida%' THEN
      v_calificacion := 'NO PROCEDE';
      v_puntaje := 25;
      v_motivo := 'Calificacion SBS restrictiva del cliente.';
    ELSIF v_ratio > 3 THEN
      v_calificacion := 'NO PROCEDE';
      v_puntaje := 20;
      v_motivo := 'El monto supera 3 veces los ingresos estimados.';
    ELSIF v_ratio <= 0.5 AND coalesce(v_solicitud.plazo_meses, 0) >= 12 THEN
      v_calificacion := 'APTO';
      v_puntaje := 85;
      v_motivo := 'Perfil compatible con microcredito comercial. Puede continuar.';
    ELSIF v_ratio > 1.5 OR coalesce(v_solicitud.monto_solicitado, 0) > 30000 THEN
      v_calificacion := 'REVISAR';
      v_puntaje := 55;
      v_motivo := 'Relacion monto/ingreso elevada. Se recomienda analisis adicional.';
    ELSIF lower(coalesce(v_solicitud.calificacion_sbs, '')) LIKE '%deficiente%'
       OR lower(coalesce(v_solicitud.calificacion_sbs, '')) LIKE '%cpp%' THEN
      v_calificacion := 'REVISAR';
      v_puntaje := 45;
      v_motivo := 'Cliente con calificacion SBS que requiere comite.';
    ELSE
      v_calificacion := 'APTO';
      v_puntaje := 78;
      v_motivo := 'Perfil compatible con microcredito comercial.';
    END IF;
  END IF;

  INSERT INTO public.pre_evaluaciones_solicitud (
    solicitud_id, asesor_id, calificacion, puntaje, motivo
  )
  VALUES (
    p_solicitud_id,
    public.current_asesor_id(),
    v_calificacion,
    v_puntaje,
    v_motivo
  )
  ON CONFLICT (solicitud_id) DO UPDATE SET
    asesor_id = excluded.asesor_id,
    calificacion = excluded.calificacion,
    puntaje = excluded.puntaje,
    motivo = excluded.motivo,
    created_at = now();

  RETURN jsonb_build_object(
    'calificacion', v_calificacion,
    'puntaje_estimado', v_puntaje,
    'motivo', v_motivo
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.pre_evaluar_solicitud_app_cliente(uuid) TO authenticated;

-- Tomar caso: asignar asesor + fila en cartera NUEVA_SOLICITUD
CREATE OR REPLACE FUNCTION public.asignar_solicitud_app_cliente(p_solicitud_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_asesor_id uuid := public.current_asesor_id();
  v_agencia_id uuid := public.current_agencia_id();
  v_solicitud record;
  v_cartera_id uuid;
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden tomar casos.';
  END IF;

  IF v_asesor_id IS NULL OR v_agencia_id IS NULL THEN
    RAISE EXCEPTION 'Perfil de asesor incompleto.';
  END IF;

  SELECT * INTO v_solicitud
  FROM public.solicitudes_credito
  WHERE id = p_solicitud_id
    AND origen = 'app_cliente'
    AND asesor_id IS NULL
    AND estado = 'pendiente'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no disponible para asignacion.';
  END IF;

  UPDATE public.solicitudes_credito
  SET
    asesor_id = v_asesor_id,
    agencia_id = v_agencia_id,
    estado = 'en_evaluacion',
    updated_at = now()
  WHERE id = p_solicitud_id;

  INSERT INTO public.cartera_diaria (
    asesor_id,
    cliente_id,
    agencia_id,
    fecha_asignacion,
    tipo_gestion,
    prioridad,
    score_prioridad,
    estado_visita,
    solicitud_id
  )
  VALUES (
    v_asesor_id,
    v_solicitud.cliente_id,
    v_agencia_id,
    current_date,
    'NUEVA_SOLICITUD',
    'normal',
    38,
    'pendiente',
    p_solicitud_id
  )
  ON CONFLICT (asesor_id, cliente_id, fecha_asignacion) DO UPDATE SET
    tipo_gestion = 'NUEVA_SOLICITUD',
    prioridad = 'normal',
    score_prioridad = 38,
    solicitud_id = excluded.solicitud_id,
    estado_visita = CASE
      WHEN public.cartera_diaria.estado_visita = 'visitado' THEN public.cartera_diaria.estado_visita
      ELSE 'pendiente'
    END
  RETURNING id INTO v_cartera_id;

  UPDATE public.solicitudes_credito
  SET cartera_diaria_id = v_cartera_id
  WHERE id = p_solicitud_id;

  RETURN v_cartera_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.asignar_solicitud_app_cliente(uuid) TO authenticated;

-- Registrar visita de campo ligada al expediente app_cliente
CREATE OR REPLACE FUNCTION public.registrar_visita_solicitud_app_cliente(
  p_solicitud_id uuid,
  p_lat numeric DEFAULT NULL,
  p_lng numeric DEFAULT NULL,
  p_observacion text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
  v_cartera_id uuid;
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden registrar visitas.';
  END IF;

  SELECT * INTO v_solicitud
  FROM public.solicitudes_credito
  WHERE id = p_solicitud_id
    AND origen = 'app_cliente'
    AND asesor_id = public.current_asesor_id();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada o no asignada a usted.';
  END IF;

  v_cartera_id := v_solicitud.cartera_diaria_id;

  IF v_cartera_id IS NULL THEN
    SELECT id INTO v_cartera_id
    FROM public.cartera_diaria
    WHERE solicitud_id = p_solicitud_id
      AND asesor_id = public.current_asesor_id()
    ORDER BY fecha_asignacion DESC
    LIMIT 1;
  END IF;

  IF v_cartera_id IS NULL THEN
    RAISE EXCEPTION 'No hay registro de cartera para esta solicitud.';
  END IF;

  UPDATE public.cartera_diaria
  SET
    estado_visita = 'visitado',
    resultado_visita = 'Visitado',
    observacion_visita = coalesce(nullif(btrim(p_observacion), ''), observacion_visita, 'Visita registrada desde expediente app clientes'),
    timestamp_visita = now(),
    lat_visita = coalesce(p_lat, lat_visita),
    lng_visita = coalesce(p_lng, lng_visita)
  WHERE id = v_cartera_id;

  UPDATE public.solicitudes_credito
  SET
    lat_captura = coalesce(p_lat, lat_captura),
    lng_captura = coalesce(p_lng, lng_captura),
    updated_at = now()
  WHERE id = p_solicitud_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_visita_solicitud_app_cliente(uuid, numeric, numeric, text)
  TO authenticated;

-- Actualizar flujo de estados: solo super_operador aprueba + checklist
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
END;
$$;

-- Super operador: lectura de solicitudes app_cliente de su agencia (para aprobar)
DROP POLICY IF EXISTS super_operador_solicitudes_app_cliente ON public.solicitudes_credito;
CREATE POLICY super_operador_solicitudes_app_cliente
  ON public.solicitudes_credito
  FOR SELECT
  TO authenticated
  USING (
    public.current_asesor_perfil() = 'super_operador'
    AND origen = 'app_cliente'
    AND agencia_id = public.current_agencia_id()
  );

DROP POLICY IF EXISTS super_operador_pre_eval_agencia ON public.pre_evaluaciones_solicitud;
CREATE POLICY super_operador_pre_eval_agencia
  ON public.pre_evaluaciones_solicitud
  FOR SELECT
  TO authenticated
  USING (
    public.current_asesor_perfil() = 'super_operador'
    AND EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      WHERE sc.id = pre_evaluaciones_solicitud.solicitud_id
        AND sc.agencia_id = public.current_agencia_id()
    )
  );

DROP POLICY IF EXISTS super_operador_buro_agencia ON public.consultas_buro;
CREATE POLICY super_operador_buro_agencia
  ON public.consultas_buro
  FOR SELECT
  TO authenticated
  USING (
    public.current_asesor_perfil() = 'super_operador'
    AND EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      WHERE sc.id = consultas_buro.solicitud_id
        AND sc.agencia_id = public.current_agencia_id()
    )
  );

DROP POLICY IF EXISTS super_operador_cartera_agencia ON public.cartera_diaria;
CREATE POLICY super_operador_cartera_agencia
  ON public.cartera_diaria
  FOR SELECT
  TO authenticated
  USING (
    public.current_asesor_perfil() = 'super_operador'
    AND agencia_id = public.current_agencia_id()
  );
