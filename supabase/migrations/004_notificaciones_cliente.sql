-- Notificaciones in-app para clientes

CREATE TABLE IF NOT EXISTS public.notificaciones_cliente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  tipo character varying NOT NULL,
  titulo character varying NOT NULL,
  mensaje text NOT NULL,
  referencia_tipo character varying,
  referencia_id uuid,
  leida boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_cliente_id
  ON public.notificaciones_cliente(cliente_id, leida, created_at DESC);

ALTER TABLE public.notificaciones_cliente ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notificaciones_select_own ON public.notificaciones_cliente;
CREATE POLICY notificaciones_select_own ON public.notificaciones_cliente
  FOR SELECT TO authenticated
  USING (cliente_id = public.cliente_id_actual());

DROP POLICY IF EXISTS notificaciones_update_own ON public.notificaciones_cliente;
CREATE POLICY notificaciones_update_own ON public.notificaciones_cliente
  FOR UPDATE TO authenticated
  USING (cliente_id = public.cliente_id_actual())
  WITH CHECK (cliente_id = public.cliente_id_actual());

-- Notificar al cliente cuando cambia el estado de su solicitud
CREATE OR REPLACE FUNCTION public.notify_cliente_solicitud_estado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_titulo text;
  v_mensaje text;
BEGIN
  IF TG_OP = 'INSERT'
     AND NEW.origen = 'app_cliente'
     AND NEW.estado = 'pendiente' THEN
    INSERT INTO public.notificaciones_cliente (
      cliente_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
    )
    VALUES (
      NEW.cliente_id,
      'solicitud_estado',
      'Solicitud enviada',
      'Tu solicitud ' || COALESCE(NEW.numero_expediente, '') ||
        ' fue enviada. Sube tus documentos para agilizar la revision.',
      'solicitud',
      NEW.id
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.estado IS DISTINCT FROM NEW.estado THEN
    v_titulo := CASE NEW.estado
      WHEN 'pendiente' THEN 'Solicitud recibida'
      WHEN 'en_evaluacion' THEN 'Solicitud en evaluacion'
      WHEN 'observada' THEN 'Documentos requeridos'
      WHEN 'aprobada' THEN 'Credito aprobado'
      WHEN 'rechazada' THEN 'Solicitud no aprobada'
      WHEN 'desembolsada' THEN 'Credito desembolsado'
      ELSE 'Actualizacion de solicitud'
    END;

    v_mensaje := CASE NEW.estado
      WHEN 'pendiente' THEN 'Tu solicitud ' || COALESCE(NEW.numero_expediente, '') || ' fue recibida y esta en revision.'
      WHEN 'en_evaluacion' THEN 'Un asesor esta evaluando tu solicitud ' || COALESCE(NEW.numero_expediente, '') || '.'
      WHEN 'observada' THEN 'Necesitamos documentos adicionales para tu solicitud. Revisa el detalle en la app.'
      WHEN 'aprobada' THEN 'Felicitaciones, tu solicitud fue aprobada.'
      WHEN 'rechazada' THEN COALESCE(NEW.motivo_rechazo, 'Tu solicitud no fue aprobada en esta ocasion.')
      WHEN 'desembolsada' THEN 'Tu credito fue desembolsado. Ya puedes verlo en Mis Creditos.'
      ELSE 'El estado de tu solicitud cambio a ' || NEW.estado || '.'
    END;

    INSERT INTO public.notificaciones_cliente (
      cliente_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
    )
    VALUES (
      NEW.cliente_id,
      'solicitud_estado',
      v_titulo,
      v_mensaje,
      'solicitud',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_cliente_solicitud ON public.solicitudes_credito;
CREATE TRIGGER trg_notify_cliente_solicitud
  AFTER INSERT OR UPDATE OF estado ON public.solicitudes_credito
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_cliente_solicitud_estado();

-- Realtime (habilitar en dashboard si falla el alter)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones_cliente;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;
