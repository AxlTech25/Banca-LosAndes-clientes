-- =============================================================================
-- Fase 3 — movimientos de cuenta, mi asesor, recuperacion de contrasena
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Movimientos de cuenta
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.movimientos_cuenta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cuenta_id uuid NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  tipo character varying NOT NULL
    CHECK (tipo IN (
      'deposito',
      'transferencia_salida',
      'transferencia_entrada',
      'pago_credito',
      'ajuste'
    )),
  monto numeric NOT NULL CHECK (monto > 0),
  saldo_resultante numeric NOT NULL CHECK (saldo_resultante >= 0),
  concepto character varying,
  referencia character varying,
  cuenta_destino character varying,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_movimientos_cuenta_cuenta_id
  ON public.movimientos_cuenta(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_cuenta_cliente_id
  ON public.movimientos_cuenta(cliente_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_cuenta_created_at
  ON public.movimientos_cuenta(created_at DESC);

ALTER TABLE public.movimientos_cuenta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS movimientos_select_own ON public.movimientos_cuenta;
CREATE POLICY movimientos_select_own ON public.movimientos_cuenta
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- Deposito simulado a la cuenta de ahorros del cliente
CREATE OR REPLACE FUNCTION public.registrar_deposito_simulado(
  p_monto numeric,
  p_concepto text DEFAULT 'Deposito simulado'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_cuenta record;
  v_nuevo_saldo numeric;
  v_mov_id uuid;
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  IF p_monto <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  SELECT * INTO v_cuenta
  FROM public.cuentas
  WHERE cliente_id = v_cliente_id AND tipo = 'ahorros' AND activa = true
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta de ahorros no encontrada';
  END IF;

  v_nuevo_saldo := COALESCE(v_cuenta.saldo_disponible, 0) + p_monto;

  UPDATE public.cuentas
  SET saldo_disponible = v_nuevo_saldo
  WHERE id = v_cuenta.id;

  INSERT INTO public.movimientos_cuenta (
    cuenta_id, cliente_id, tipo, monto, saldo_resultante, concepto, referencia
  )
  VALUES (
    v_cuenta.id,
    v_cliente_id,
    'deposito',
    p_monto,
    v_nuevo_saldo,
    COALESCE(NULLIF(trim(p_concepto), ''), 'Deposito simulado'),
    'DEP-' || to_char(now(), 'YYYYMMDDHH24MISS')
  )
  RETURNING id INTO v_mov_id;

  RETURN v_mov_id;
END;
$$;

-- Transferencia simulada entre cuentas del banco (por numero de cuenta)
CREATE OR REPLACE FUNCTION public.registrar_transferencia_simulada(
  p_numero_cuenta_destino text,
  p_monto numeric,
  p_concepto text DEFAULT 'Transferencia'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_origen record;
  v_destino record;
  v_nuevo_saldo_origen numeric;
  v_nuevo_saldo_destino numeric;
  v_mov_id uuid;
  v_ref text := 'TRF-' || to_char(now(), 'YYYYMMDDHH24MISS');
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;

  p_numero_cuenta_destino := trim(p_numero_cuenta_destino);

  IF p_monto <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  SELECT * INTO v_origen
  FROM public.cuentas
  WHERE cliente_id = v_cliente_id AND tipo = 'ahorros' AND activa = true
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta de ahorros no encontrada';
  END IF;

  IF v_origen.numero_cuenta = p_numero_cuenta_destino THEN
    RAISE EXCEPTION 'No puedes transferir a la misma cuenta';
  END IF;

  IF COALESCE(v_origen.saldo_disponible, 0) < p_monto THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;

  SELECT * INTO v_destino
  FROM public.cuentas
  WHERE numero_cuenta = p_numero_cuenta_destino AND activa = true
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta destino no encontrada';
  END IF;

  v_nuevo_saldo_origen := COALESCE(v_origen.saldo_disponible, 0) - p_monto;
  v_nuevo_saldo_destino := COALESCE(v_destino.saldo_disponible, 0) + p_monto;

  UPDATE public.cuentas SET saldo_disponible = v_nuevo_saldo_origen WHERE id = v_origen.id;
  UPDATE public.cuentas SET saldo_disponible = v_nuevo_saldo_destino WHERE id = v_destino.id;

  INSERT INTO public.movimientos_cuenta (
    cuenta_id, cliente_id, tipo, monto, saldo_resultante, concepto, referencia, cuenta_destino
  )
  VALUES (
    v_origen.id,
    v_cliente_id,
    'transferencia_salida',
    p_monto,
    v_nuevo_saldo_origen,
    COALESCE(NULLIF(trim(p_concepto), ''), 'Transferencia'),
    v_ref,
    p_numero_cuenta_destino
  )
  RETURNING id INTO v_mov_id;

  INSERT INTO public.movimientos_cuenta (
    cuenta_id, cliente_id, tipo, monto, saldo_resultante, concepto, referencia, cuenta_destino
  )
  VALUES (
    v_destino.id,
    v_destino.cliente_id,
    'transferencia_entrada',
    p_monto,
    v_nuevo_saldo_destino,
    COALESCE(NULLIF(trim(p_concepto), ''), 'Transferencia recibida'),
    v_ref,
    v_origen.numero_cuenta
  );

  RETURN v_mov_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. Mi asesor (datos limitados para el cliente)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cliente_asesor_principal()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_result jsonb;
BEGIN
  IF v_cliente_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_build_object(
    'asesor_id', an.id,
    'nombres', an.nombres,
    'apellidos', an.apellidos,
    'codigo_empleado', an.codigo_empleado,
    'agencia', ag.nombre,
    'region', ag.region,
    'origen', 'credito'
  )
  INTO v_result
  FROM public.creditos cr
  JOIN public.asesores_negocio an ON an.id = cr.asesor_id AND an.activo = true
  JOIN public.agencias ag ON ag.id = cr.agencia_id
  WHERE cr.cliente_id = v_cliente_id
  ORDER BY cr.created_at DESC
  LIMIT 1;

  IF v_result IS NOT NULL THEN
    RETURN v_result;
  END IF;

  SELECT jsonb_build_object(
    'asesor_id', an.id,
    'nombres', an.nombres,
    'apellidos', an.apellidos,
    'codigo_empleado', an.codigo_empleado,
    'agencia', ag.nombre,
    'region', ag.region,
    'origen', 'solicitud'
  )
  INTO v_result
  FROM public.solicitudes_credito sc
  JOIN public.asesores_negocio an ON an.id = sc.asesor_id AND an.activo = true
  JOIN public.agencias ag ON ag.id = sc.agencia_id
  WHERE sc.cliente_id = v_cliente_id
    AND sc.asesor_id IS NOT NULL
  ORDER BY sc.created_at DESC
  LIMIT 1;

  RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Recuperacion de contrasena (hint por DNI, sin exponer datos sensibles)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cliente_hint_recuperacion(p_dni text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_telefono text;
  v_masked_email text;
  v_masked_telefono text;
BEGIN
  p_dni := trim(p_dni);
  IF length(p_dni) < 8 THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT c.email, c.telefono
  INTO v_email, v_telefono
  FROM public.clientes c
  WHERE c.numero_documento = p_dni
    AND c.user_id IS NOT NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  IF v_email IS NOT NULL AND v_email <> '' AND position('@' in v_email) > 1 THEN
    v_masked_email := left(v_email, 1)
      || repeat('*', greatest(1, position('@' in v_email) - 2))
      || substring(v_email from position('@' in v_email));
  END IF;

  IF v_telefono IS NOT NULL AND length(trim(v_telefono)) >= 4 THEN
    v_masked_telefono := repeat('*', greatest(0, length(trim(v_telefono)) - 3))
      || right(trim(v_telefono), 3);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'email_masked', v_masked_email,
    'telefono_masked', v_masked_telefono
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_deposito_simulado(numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_transferencia_simulada(text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cliente_asesor_principal() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cliente_hint_recuperacion(text) TO anon, authenticated;

-- Realtime movimientos + cuentas (saldo)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'movimientos_cuenta'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.movimientos_cuenta;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'cuentas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cuentas;
  END IF;
END $$;
