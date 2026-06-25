-- Cronograma de cuotas al aprobar solicitud app_cliente

ALTER TABLE public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS fecha_desembolso_programada date,
  ADD COLUMN IF NOT EXISTS cuota_mensual_aprobada numeric(12, 2);

CREATE TABLE IF NOT EXISTS public.solicitudes_cronograma_cuotas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL REFERENCES public.solicitudes_credito (id) ON DELETE CASCADE,
  numero_cuota integer NOT NULL CHECK (numero_cuota > 0),
  fecha_pago date NOT NULL,
  monto_cuota numeric(12, 2) NOT NULL,
  capital numeric(12, 2) NOT NULL,
  interes numeric(12, 2) NOT NULL,
  saldo numeric(12, 2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (solicitud_id, numero_cuota)
);

CREATE INDEX IF NOT EXISTS idx_cronograma_solicitud
  ON public.solicitudes_cronograma_cuotas (solicitud_id, numero_cuota);

ALTER TABLE public.solicitudes_cronograma_cuotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cronograma_select_cliente ON public.solicitudes_cronograma_cuotas;
CREATE POLICY cronograma_select_cliente
  ON public.solicitudes_cronograma_cuotas
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      INNER JOIN public.clientes c ON c.id = sc.cliente_id
      WHERE sc.id = solicitud_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS cronograma_select_asesor ON public.solicitudes_cronograma_cuotas;
CREATE POLICY cronograma_select_asesor
  ON public.solicitudes_cronograma_cuotas
  FOR SELECT
  TO authenticated
  USING (
    public.es_asesor_activo()
    AND EXISTS (
      SELECT 1
      FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND (
          sc.asesor_id = public.current_asesor_id()
          OR (
            public.current_asesor_perfil() = 'super_operador'
            AND sc.agencia_id = public.current_agencia_id()
          )
        )
    )
  );

-- TEM mensual desde TEA anual (%)
CREATE OR REPLACE FUNCTION public._tem_desde_tea(p_tea numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT power(1 + (p_tea / 100.0), 1.0 / 12.0) - 1;
$$;

CREATE OR REPLACE FUNCTION public.generar_cronograma_solicitud_aprobada(
  p_solicitud_id uuid,
  p_fecha_desembolso date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
  v_tem numeric;
  v_cuota numeric;
  v_saldo numeric;
  v_capital numeric;
  v_interes numeric;
  v_monto numeric;
  v_plazo integer;
  v_tea numeric;
  v_fecha_desembolso date;
  v_fecha_pago date;
  v_n integer;
  v_dia_pago integer := 15;
BEGIN
  SELECT *
  INTO v_solicitud
  FROM public.solicitudes_credito
  WHERE id = p_solicitud_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada.';
  END IF;

  v_monto := coalesce(v_solicitud.monto_aprobado, v_solicitud.monto_solicitado);
  v_plazo := coalesce(v_solicitud.plazo_meses, 0);
  v_tea := coalesce(v_solicitud.tea_referencial, 43.92);

  IF v_monto <= 0 OR v_plazo <= 0 THEN
    RETURN;
  END IF;

  v_fecha_desembolso := coalesce(
    p_fecha_desembolso,
    v_solicitud.fecha_desembolso_programada,
    current_date
  );

  v_tem := public._tem_desde_tea(v_tea);

  IF v_tem <= 0 THEN
    v_cuota := round(v_monto / v_plazo, 2);
  ELSE
    v_cuota := round(
      v_monto * v_tem * power(1 + v_tem, v_plazo)
      / (power(1 + v_tem, v_plazo) - 1),
      2
    );
  END IF;

  DELETE FROM public.solicitudes_cronograma_cuotas
  WHERE solicitud_id = p_solicitud_id;

  v_saldo := v_monto;

  -- Primera cuota: mes siguiente al desembolso, dia 15
  v_fecha_pago := (
    date_trunc('month', v_fecha_desembolso) + interval '1 month'
    + (least(v_dia_pago, extract(day from (
        date_trunc('month', v_fecha_desembolso) + interval '2 month' - interval '1 day'
      ))::integer) - 1) * interval '1 day'
  )::date;

  FOR v_n IN 1..v_plazo LOOP
    v_interes := round(v_saldo * v_tem, 2);
    v_capital := round(v_cuota - v_interes, 2);

    IF v_n = v_plazo THEN
      v_capital := round(v_saldo, 2);
    END IF;

    v_saldo := greatest(0, round(v_saldo - v_capital, 2));

    INSERT INTO public.solicitudes_cronograma_cuotas (
      solicitud_id,
      numero_cuota,
      fecha_pago,
      monto_cuota,
      capital,
      interes,
      saldo
    ) VALUES (
      p_solicitud_id,
      v_n,
      v_fecha_pago,
      CASE WHEN v_n = v_plazo THEN round(v_capital + v_interes, 2) ELSE v_cuota END,
      v_capital,
      v_interes,
      v_saldo
    );

    v_fecha_pago := (
      date_trunc('month', v_fecha_pago) + interval '1 month'
      + (least(v_dia_pago, extract(day from (
          date_trunc('month', v_fecha_pago) + interval '2 month' - interval '1 day'
        ))::integer) - 1) * interval '1 day'
    )::date;
  END LOOP;

  UPDATE public.solicitudes_credito
  SET
    fecha_desembolso_programada = v_fecha_desembolso,
    cuota_mensual_aprobada = v_cuota,
    cuota_estimada = coalesce(cuota_estimada, v_cuota),
    updated_at = now()
  WHERE id = p_solicitud_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generar_cronograma_solicitud_aprobada(uuid, date)
  TO authenticated;

-- Extiende aprobacion: genera cronograma persistido para el cliente
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
  END IF;
END;
$$;
