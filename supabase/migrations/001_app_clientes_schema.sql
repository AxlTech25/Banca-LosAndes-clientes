-- =============================================================================
-- Banco Los Andes — App Clientes
-- Ejecutar en el SQL Editor de Supabase (proyecto compartido con app operadores)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extensiones al schema existente
-- -----------------------------------------------------------------------------

ALTER TABLE public.clientes
  ADD COLUMN IF NOT EXISTS user_id uuid UNIQUE REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS token_fcm text;

CREATE INDEX IF NOT EXISTS idx_clientes_user_id ON public.clientes(user_id);
CREATE INDEX IF NOT EXISTS idx_clientes_numero_documento ON public.clientes(numero_documento);

-- Solicitudes iniciadas desde la app cliente pueden crearse sin asesor/agencia
ALTER TABLE public.solicitudes_credito
  ALTER COLUMN asesor_id DROP NOT NULL;

ALTER TABLE public.solicitudes_credito
  ALTER COLUMN agencia_id DROP NOT NULL;

ALTER TABLE public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS origen character varying NOT NULL DEFAULT 'app_operador';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'solicitudes_credito_origen_check'
  ) THEN
    ALTER TABLE public.solicitudes_credito
      ADD CONSTRAINT solicitudes_credito_origen_check
      CHECK (origen IN ('app_cliente', 'app_operador', 'campana'));
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Tablas nuevas
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cuentas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  numero_cuenta character varying NOT NULL UNIQUE,
  tipo character varying NOT NULL DEFAULT 'ahorros',
  moneda character varying NOT NULL DEFAULT 'PEN',
  saldo_disponible numeric NOT NULL DEFAULT 0 CHECK (saldo_disponible >= 0),
  activa boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cuentas_cliente_id ON public.cuentas(cliente_id);

CREATE TABLE IF NOT EXISTS public.pagos_credito (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  credito_id uuid NOT NULL REFERENCES public.creditos(id),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id),
  monto numeric NOT NULL CHECK (monto > 0),
  tipo character varying NOT NULL DEFAULT 'cuota'
    CHECK (tipo IN ('cuota', 'abono', 'liquidacion')),
  metodo_pago character varying NOT NULL DEFAULT 'simulado'
    CHECK (metodo_pago IN ('simulado', 'yape', 'transferencia', 'agente')),
  estado character varying NOT NULL DEFAULT 'confirmado'
    CHECK (estado IN ('pendiente', 'confirmado', 'rechazado')),
  referencia character varying,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pagos_credito_credito_id ON public.pagos_credito(credito_id);
CREATE INDEX IF NOT EXISTS idx_pagos_credito_cliente_id ON public.pagos_credito(cliente_id);

CREATE TABLE IF NOT EXISTS public.solicitudes_historial_estado (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id uuid NOT NULL REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  estado_anterior character varying,
  estado_nuevo character varying NOT NULL,
  observacion text,
  actor_tipo character varying NOT NULL
    CHECK (actor_tipo IN ('cliente', 'asesor', 'sistema')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_solicitudes_historial_solicitud_id
  ON public.solicitudes_historial_estado(solicitud_id);

-- -----------------------------------------------------------------------------
-- 3. Helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cliente_id_actual()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.clientes WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.es_asesor_activo()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.asesores_negocio
    WHERE user_id = auth.uid() AND activo = true
  );
$$;

-- Vincula o crea el perfil de cliente tras el registro en auth
CREATE OR REPLACE FUNCTION public.vincular_cliente_registro(
  p_dni text,
  p_nombres text,
  p_apellidos text,
  p_email text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cliente_id uuid;
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para vincular tu perfil';
  END IF;

  p_dni := trim(p_dni);
  IF length(p_dni) < 8 THEN
    RAISE EXCEPTION 'DNI invalido';
  END IF;

  SELECT id INTO v_cliente_id
  FROM public.clientes
  WHERE numero_documento = p_dni;

  IF v_cliente_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.clientes
      WHERE id = v_cliente_id
        AND user_id IS NOT NULL
        AND user_id <> v_user_id
    ) THEN
      RAISE EXCEPTION 'Este DNI ya tiene una cuenta vinculada';
    END IF;

    UPDATE public.clientes
    SET
      user_id = v_user_id,
      nombres = p_nombres,
      apellidos = p_apellidos,
      email = COALESCE(NULLIF(trim(p_email), ''), email),
      updated_at = now()
    WHERE id = v_cliente_id;
  ELSE
    INSERT INTO public.clientes (
      user_id,
      numero_documento,
      tipo_documento,
      nombres,
      apellidos,
      email
    )
    VALUES (
      v_user_id,
      p_dni,
      'DNI',
      p_nombres,
      p_apellidos,
      NULLIF(trim(p_email), '')
    )
    RETURNING id INTO v_cliente_id;
  END IF;

  INSERT INTO public.cuentas (cliente_id, numero_cuenta, tipo, moneda, saldo_disponible)
  SELECT v_cliente_id, '001-' || p_dni, 'ahorros', 'PEN', 0
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cuentas
    WHERE cliente_id = v_cliente_id AND tipo = 'ahorros' AND activa = true
  );

  RETURN v_cliente_id;
END;
$$;

-- Pago simulado: registra el pago y actualiza el credito
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
DECLARE
  v_cliente_id uuid := public.cliente_id_actual();
  v_pago_id uuid;
  v_credito record;
BEGIN
  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Cliente no encontrado';
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
    'simulado',
    'confirmado',
    'SIM-' || to_char(now(), 'YYYYMMDDHH24MISS')
  )
  RETURNING id INTO v_pago_id;

  UPDATE public.creditos
  SET
    cuotas_pagadas = LEAST(cuotas_total, cuotas_pagadas + 1),
    saldo_actual = GREATEST(0, COALESCE(saldo_actual, 0) - p_monto),
    dias_mora = CASE WHEN dias_mora > 0 THEN 0 ELSE dias_mora END,
    estado = CASE
      WHEN GREATEST(0, COALESCE(saldo_actual, 0) - p_monto) <= 0 THEN 'cancelado'
      ELSE estado
    END
  WHERE id = p_credito_id;

  RETURN v_pago_id;
END;
$$;

-- Historial automatico al cambiar estado de solicitud
CREATE OR REPLACE FUNCTION public.log_solicitud_estado_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO public.solicitudes_historial_estado (
      solicitud_id,
      estado_anterior,
      estado_nuevo,
      actor_tipo
    )
    VALUES (
      NEW.id,
      OLD.estado,
      NEW.estado,
      CASE
        WHEN public.es_asesor_activo() THEN 'asesor'
        WHEN public.cliente_id_actual() IS NOT NULL THEN 'cliente'
        ELSE 'sistema'
      END
    );
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO public.solicitudes_historial_estado (
      solicitud_id,
      estado_anterior,
      estado_nuevo,
      actor_tipo
    )
    VALUES (
      NEW.id,
      NULL,
      NEW.estado,
      CASE
        WHEN NEW.origen = 'app_cliente' THEN 'cliente'
        ELSE 'asesor'
      END
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_solicitud_estado_historial ON public.solicitudes_credito;
CREATE TRIGGER trg_solicitud_estado_historial
  AFTER INSERT OR UPDATE OF estado ON public.solicitudes_credito
  FOR EACH ROW
  EXECUTE FUNCTION public.log_solicitud_estado_change();

-- -----------------------------------------------------------------------------
-- 4. Row Level Security
-- -----------------------------------------------------------------------------

ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creditos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creditos_preaprobados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campanas_activas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_historial_estado ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agencias ENABLE ROW LEVEL SECURITY;

-- clientes
DROP POLICY IF EXISTS clientes_select_own ON public.clientes;
CREATE POLICY clientes_select_own ON public.clientes
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.es_asesor_activo());

DROP POLICY IF EXISTS clientes_update_own ON public.clientes;
CREATE POLICY clientes_update_own ON public.clientes
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- cuentas
DROP POLICY IF EXISTS cuentas_select_own ON public.cuentas;
CREATE POLICY cuentas_select_own ON public.cuentas
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- creditos
DROP POLICY IF EXISTS creditos_select_own ON public.creditos;
CREATE POLICY creditos_select_own ON public.creditos
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- creditos_preaprobados
DROP POLICY IF EXISTS preaprobados_select_own ON public.creditos_preaprobados;
CREATE POLICY preaprobados_select_own ON public.creditos_preaprobados
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- campanas_activas
DROP POLICY IF EXISTS campanas_select_own ON public.campanas_activas;
CREATE POLICY campanas_select_own ON public.campanas_activas
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- solicitudes_credito
DROP POLICY IF EXISTS solicitudes_select_own ON public.solicitudes_credito;
CREATE POLICY solicitudes_select_own ON public.solicitudes_credito
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

DROP POLICY IF EXISTS solicitudes_insert_cliente ON public.solicitudes_credito;
CREATE POLICY solicitudes_insert_cliente ON public.solicitudes_credito
  FOR INSERT TO authenticated
  WITH CHECK (
    cliente_id = public.cliente_id_actual()
    AND origen = 'app_cliente'
    AND estado IN ('borrador', 'pendiente')
  );

DROP POLICY IF EXISTS solicitudes_update_cliente ON public.solicitudes_credito;
CREATE POLICY solicitudes_update_cliente ON public.solicitudes_credito
  FOR UPDATE TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    AND estado IN ('borrador', 'observada')
  )
  WITH CHECK (
    cliente_id = public.cliente_id_actual()
    AND estado IN ('borrador', 'pendiente', 'observada')
  );

-- solicitudes_documentos
DROP POLICY IF EXISTS solicitud_docs_select_own ON public.solicitudes_documentos;
CREATE POLICY solicitud_docs_select_own ON public.solicitudes_documentos
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND (
          sc.cliente_id = public.cliente_id_actual()
          OR public.es_asesor_activo()
        )
    )
  );

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

-- historial de solicitudes
DROP POLICY IF EXISTS historial_select_own ON public.solicitudes_historial_estado;
CREATE POLICY historial_select_own ON public.solicitudes_historial_estado
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.solicitudes_credito sc
      WHERE sc.id = solicitud_id
        AND (
          sc.cliente_id = public.cliente_id_actual()
          OR public.es_asesor_activo()
        )
    )
  );

-- pagos
DROP POLICY IF EXISTS pagos_select_own ON public.pagos_credito;
CREATE POLICY pagos_select_own ON public.pagos_credito
  FOR SELECT TO authenticated
  USING (
    cliente_id = public.cliente_id_actual()
    OR public.es_asesor_activo()
  );

-- agencias: lectura publica para clientes autenticados
DROP POLICY IF EXISTS agencias_select_activas ON public.agencias;
CREATE POLICY agencias_select_activas ON public.agencias
  FOR SELECT TO authenticated
  USING (activa = true OR public.es_asesor_activo());

-- -----------------------------------------------------------------------------
-- 5. Permisos de funciones RPC
-- -----------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION public.cliente_id_actual() TO authenticated;
GRANT EXECUTE ON FUNCTION public.vincular_cliente_registro(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_pago_simulado(uuid, numeric, text) TO authenticated;

-- Nota: deshabilitar confirmacion de email en Supabase Auth para desarrollo:
-- Authentication > Providers > Email > "Confirm email" = OFF
