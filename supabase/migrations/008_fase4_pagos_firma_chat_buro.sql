-- =============================================================================
-- Fase 4 — pagos reales (simulados), firma digital, chat, buró resumido
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Chat cliente ↔ asesor por solicitud
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 2. Pagos con metodo (pendiente → confirmado)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.registrar_pago_credito(
  p_credito_id uuid,
  p_monto numeric,
  p_metodo_pago text DEFAULT 'yape',
  p_tipo text DEFAULT 'cuota'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_pago_id uuid;
  v_credito record;
  v_metodo text := lower(trim(COALESCE(p_metodo_pago, 'yape')));
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  IF v_metodo NOT IN ('yape', 'transferencia', 'agente', 'simulado') THEN
    RAISE EXCEPTION 'Metodo de pago no valido';
  END IF;

  SELECT * INTO v_credito
  FROM public.creditos
  WHERE id = p_credito_id AND cliente_id = v_cliente_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credito no encontrado';
  END IF;

  IF p_monto <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  INSERT INTO public.pagos_credito (
    credito_id,
    cliente_id,
    monto,
    tipo,
    metodo_pago,
    estado,
    referencia
  )
  VALUES (
    p_credito_id,
    v_cliente_id,
    p_monto,
    COALESCE(p_tipo, 'cuota'),
    v_metodo,
    'pendiente',
    upper(v_metodo) || '-' || to_char(now(), 'YYYYMMDDHH24MISS')
  )
  RETURNING id INTO v_pago_id;

  IF v_metodo = 'simulado' THEN
    PERFORM public._aplicar_pago_credito_confirmado(v_pago_id);
  END IF;

  RETURN v_pago_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._aplicar_pago_credito_confirmado(p_pago_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pago record;
BEGIN
  SELECT * INTO v_pago
  FROM public.pagos_credito
  WHERE id = p_pago_id
  FOR UPDATE;

  IF NOT FOUND OR v_pago.estado = 'confirmado' THEN
    RETURN;
  END IF;

  UPDATE public.pagos_credito
  SET estado = 'confirmado'
  WHERE id = p_pago_id;

  UPDATE public.creditos
  SET
    cuotas_pagadas = LEAST(cuotas_total, cuotas_pagadas + 1),
    saldo_actual = GREATEST(0, COALESCE(saldo_actual, 0) - v_pago.monto),
    dias_mora = CASE WHEN dias_mora > 0 THEN 0 ELSE dias_mora END,
    estado = CASE
      WHEN GREATEST(0, COALESCE(saldo_actual, 0) - v_pago.monto) <= 0 THEN 'cancelado'
      ELSE estado
    END
  WHERE id = v_pago.credito_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirmar_pago_credito(p_pago_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_pago record;
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  SELECT * INTO v_pago
  FROM public.pagos_credito
  WHERE id = p_pago_id AND cliente_id = v_cliente_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pago no encontrado';
  END IF;

  IF v_pago.estado <> 'pendiente' THEN
    RAISE EXCEPTION 'El pago ya fue procesado';
  END IF;

  PERFORM public._aplicar_pago_credito_confirmado(p_pago_id);
  RETURN p_pago_id;
END;
$$;

-- Refactor pago simulado para reutilizar logica
CREATE OR REPLACE FUNCTION public.registrar_pago_simulado(
  p_credito_id uuid,
  p_monto numeric,
  p_tipo text DEFAULT 'cuota'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.registrar_pago_credito(
    p_credito_id,
    p_monto,
    'simulado',
    COALESCE(p_tipo, 'cuota')
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Firma digital en solicitud
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.guardar_firma_solicitud(
  p_solicitud_id uuid,
  p_firma_base64 text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  IF p_firma_base64 IS NULL OR length(trim(p_firma_base64)) < 50 THEN
    RAISE EXCEPTION 'Firma invalida';
  END IF;

  UPDATE public.solicitudes_credito
  SET
    firma_cliente_base64 = p_firma_base64,
    updated_at = now()
  WHERE id = p_solicitud_id
    AND cliente_id = v_cliente_id
    AND estado IN ('borrador', 'pendiente', 'observada', 'aprobada');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se pudo guardar la firma en esta solicitud';
  END IF;

  RETURN p_solicitud_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. Buró resumido (sin exponer consultas_buro completas)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cliente_buro_resumido()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_cliente record;
  v_consulta record;
BEGIN
  IF v_cliente_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT calificacion_sbs, numero_documento
  INTO v_cliente
  FROM public.clientes
  WHERE id = v_cliente_id;

  SELECT cb.calificacion_sbs, cb.created_at, cb.entidades_con_deuda
  INTO v_consulta
  FROM public.consultas_buro cb
  WHERE cb.cliente_id = v_cliente_id
  ORDER BY cb.created_at DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'calificacion_sbs', COALESCE(v_cliente.calificacion_sbs, v_consulta.calificacion_sbs),
    'entidades_con_deuda', v_consulta.entidades_con_deuda,
    'fecha_ultima_consulta', v_consulta.created_at,
    'descripcion', CASE COALESCE(v_cliente.calificacion_sbs, v_consulta.calificacion_sbs)
      WHEN 'Normal' THEN 'Tu historial crediticio es favorable.'
      WHEN 'CPP' THEN 'Presentas problemas potenciales de pago.'
      WHEN 'Deficiente' THEN 'Tienes deudas con atraso significativo.'
      WHEN 'Dudoso' THEN 'Alta probabilidad de incobrabilidad.'
      WHEN 'Pérdida' THEN 'Deuda considerada incobrable.'
      ELSE 'Calificacion no disponible.'
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_pago_credito(uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_pago_credito(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_firma_solicitud(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cliente_buro_resumido() TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'mensajes_solicitud'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.mensajes_solicitud;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'pagos_credito'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.pagos_credito;
  END IF;
END $$;
