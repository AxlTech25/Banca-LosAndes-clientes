-- Notificaciones in-app para asesores (app clientes: solicitud, chat, pago)

CREATE TABLE IF NOT EXISTS public.notificaciones_asesor (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id uuid REFERENCES public.asesores_negocio(id) ON DELETE CASCADE,
  tipo character varying NOT NULL
    CHECK (tipo IN ('solicitud_nueva', 'chat_cliente', 'pago_pendiente')),
  titulo character varying NOT NULL,
  mensaje text NOT NULL,
  referencia_tipo character varying,
  referencia_id uuid,
  leida boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notificaciones_asesor_lectura (
  notificacion_id uuid NOT NULL
    REFERENCES public.notificaciones_asesor(id) ON DELETE CASCADE,
  asesor_id uuid NOT NULL
    REFERENCES public.asesores_negocio(id) ON DELETE CASCADE,
  leida_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notificacion_id, asesor_id)
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_asesor_asesor
  ON public.notificaciones_asesor(asesor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notificaciones_asesor_broadcast
  ON public.notificaciones_asesor(created_at DESC)
  WHERE asesor_id IS NULL;

ALTER TABLE public.notificaciones_asesor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones_asesor_lectura ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notif_asesor_select ON public.notificaciones_asesor;
CREATE POLICY notif_asesor_select ON public.notificaciones_asesor
  FOR SELECT TO authenticated
  USING (
    public.es_asesor_activo()
    AND (
      asesor_id = public.current_asesor_id()
      OR asesor_id IS NULL
    )
  );

DROP POLICY IF EXISTS notif_asesor_update ON public.notificaciones_asesor;
CREATE POLICY notif_asesor_update ON public.notificaciones_asesor
  FOR UPDATE TO authenticated
  USING (asesor_id = public.current_asesor_id())
  WITH CHECK (asesor_id = public.current_asesor_id());

DROP POLICY IF EXISTS notif_asesor_lectura_select ON public.notificaciones_asesor_lectura;
CREATE POLICY notif_asesor_lectura_select ON public.notificaciones_asesor_lectura
  FOR SELECT TO authenticated
  USING (asesor_id = public.current_asesor_id());

DROP POLICY IF EXISTS notif_asesor_lectura_insert ON public.notificaciones_asesor_lectura;
CREATE POLICY notif_asesor_lectura_insert ON public.notificaciones_asesor_lectura
  FOR INSERT TO authenticated
  WITH CHECK (asesor_id = public.current_asesor_id());

CREATE OR REPLACE FUNCTION public.marcar_notificacion_asesor_leida(p_notificacion_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notif record;
  v_asesor_id uuid := public.current_asesor_id();
BEGIN
  IF NOT public.es_asesor_activo() OR v_asesor_id IS NULL THEN
    RAISE EXCEPTION 'Solo asesores activos pueden marcar notificaciones.';
  END IF;

  SELECT * INTO v_notif
  FROM public.notificaciones_asesor
  WHERE id = p_notificacion_id
    AND (
      asesor_id = v_asesor_id
      OR asesor_id IS NULL
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notificacion no encontrada.';
  END IF;

  IF v_notif.asesor_id IS NULL THEN
    INSERT INTO public.notificaciones_asesor_lectura (notificacion_id, asesor_id)
    VALUES (p_notificacion_id, v_asesor_id)
    ON CONFLICT DO NOTHING;
  ELSE
    UPDATE public.notificaciones_asesor
    SET leida = true
    WHERE id = p_notificacion_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_asesor_solicitud_app_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.origen = 'app_cliente'
     AND NEW.estado = 'pendiente'
     AND NEW.asesor_id IS NULL THEN
    INSERT INTO public.notificaciones_asesor (
      asesor_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
    )
    VALUES (
      NULL,
      'solicitud_nueva',
      'Nueva solicitud app clientes',
      'Solicitud ' || COALESCE(NEW.numero_expediente, 'S/N') ||
        ' esperando asignacion.',
      'solicitud',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_asesor_chat_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitud record;
BEGIN
  IF NEW.autor_tipo <> 'cliente' THEN
    RETURN NEW;
  END IF;

  SELECT sc.id, sc.numero_expediente, sc.asesor_id
  INTO v_solicitud
  FROM public.solicitudes_credito sc
  WHERE sc.id = NEW.solicitud_id;

  IF v_solicitud.asesor_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notificaciones_asesor (
    asesor_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
  )
  VALUES (
    v_solicitud.asesor_id,
    'chat_cliente',
    'Mensaje de cliente',
    'Nuevo mensaje en ' || COALESCE(v_solicitud.numero_expediente, 'solicitud') || '.',
    'solicitud',
    NEW.solicitud_id
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_asesor_pago_pendiente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credito record;
BEGIN
  IF NEW.estado <> 'pendiente'
     OR NEW.metodo_pago NOT IN ('yape', 'transferencia', 'agente') THEN
    RETURN NEW;
  END IF;

  SELECT c.asesor_id, c.producto
  INTO v_credito
  FROM public.creditos c
  WHERE c.id = NEW.credito_id;

  IF v_credito.asesor_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notificaciones_asesor (
    asesor_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
  )
  VALUES (
    v_credito.asesor_id,
    'pago_pendiente',
    'Pago por confirmar',
    'Pago de S/ ' || to_char(NEW.monto, 'FM999999990.00') ||
      ' via ' || upper(NEW.metodo_pago) || ' pendiente de confirmacion.',
    'pago',
    NEW.id
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_asesor_solicitud_app ON public.solicitudes_credito;
CREATE TRIGGER trg_notify_asesor_solicitud_app
  AFTER INSERT ON public.solicitudes_credito
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_asesor_solicitud_app_cliente();

DROP TRIGGER IF EXISTS trg_notify_asesor_chat ON public.mensajes_solicitud;
CREATE TRIGGER trg_notify_asesor_chat
  AFTER INSERT ON public.mensajes_solicitud
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_asesor_chat_cliente();

DROP TRIGGER IF EXISTS trg_notify_asesor_pago ON public.pagos_credito;
CREATE TRIGGER trg_notify_asesor_pago
  AFTER INSERT ON public.pagos_credito
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_asesor_pago_pendiente();

GRANT EXECUTE ON FUNCTION public.marcar_notificacion_asesor_leida(uuid) TO authenticated;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones_asesor;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;
