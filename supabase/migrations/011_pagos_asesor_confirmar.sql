-- Pagos de credito: confirmacion / rechazo por asesor (app clientes Yape, transferencia, agente)

CREATE OR REPLACE FUNCTION public.asesor_confirmar_pago_credito(p_pago_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pago record;
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden confirmar pagos.';
  END IF;

  SELECT p.*, c.asesor_id
  INTO v_pago
  FROM public.pagos_credito p
  INNER JOIN public.creditos c ON c.id = p.credito_id
  WHERE p.id = p_pago_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pago no encontrado.';
  END IF;

  IF v_pago.asesor_id IS DISTINCT FROM public.current_asesor_id() THEN
    RAISE EXCEPTION 'Este pago no pertenece a su cartera.';
  END IF;

  IF v_pago.estado <> 'pendiente' THEN
    RAISE EXCEPTION 'El pago ya fue procesado.';
  END IF;

  IF v_pago.metodo_pago NOT IN ('yape', 'transferencia', 'agente') THEN
    RAISE EXCEPTION 'Este pago no requiere confirmacion manual.';
  END IF;

  PERFORM public._aplicar_pago_credito_confirmado(p_pago_id);
  RETURN p_pago_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.asesor_rechazar_pago_credito(
  p_pago_id uuid,
  p_motivo text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pago record;
  v_motivo text := nullif(btrim(COALESCE(p_motivo, '')), '');
BEGIN
  IF NOT public.es_asesor_activo() THEN
    RAISE EXCEPTION 'Solo asesores activos pueden rechazar pagos.';
  END IF;

  SELECT p.*, c.asesor_id
  INTO v_pago
  FROM public.pagos_credito p
  INNER JOIN public.creditos c ON c.id = p.credito_id
  WHERE p.id = p_pago_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pago no encontrado.';
  END IF;

  IF v_pago.asesor_id IS DISTINCT FROM public.current_asesor_id() THEN
    RAISE EXCEPTION 'Este pago no pertenece a su cartera.';
  END IF;

  IF v_pago.estado <> 'pendiente' THEN
    RAISE EXCEPTION 'El pago ya fue procesado.';
  END IF;

  UPDATE public.pagos_credito
  SET
    estado = 'rechazado',
    referencia = CASE
      WHEN v_motivo IS NOT NULL
        THEN COALESCE(referencia, '') || ' | Rechazado: ' || v_motivo
      ELSE referencia
    END
  WHERE id = p_pago_id;

  RETURN p_pago_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_cliente_pago_estado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.estado IS DISTINCT FROM NEW.estado
     AND NEW.estado IN ('confirmado', 'rechazado') THEN
    INSERT INTO public.notificaciones_cliente (
      cliente_id, tipo, titulo, mensaje, referencia_tipo, referencia_id
    )
    VALUES (
      NEW.cliente_id,
      'pago_credito',
      CASE NEW.estado
        WHEN 'confirmado' THEN 'Pago confirmado'
        ELSE 'Pago no confirmado'
      END,
      CASE NEW.estado
        WHEN 'confirmado' THEN
          'Tu pago de S/ ' || to_char(NEW.monto, 'FM999999990.00') ||
          ' (' || upper(COALESCE(NEW.metodo_pago, '')) || ') fue confirmado.'
        ELSE
          'Tu pago de S/ ' || to_char(NEW.monto, 'FM999999990.00') ||
          ' no pudo confirmarse. Intenta nuevamente o contacta a tu asesor.'
      END,
      'pago',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_cliente_pago ON public.pagos_credito;
CREATE TRIGGER trg_notify_cliente_pago
  AFTER UPDATE OF estado ON public.pagos_credito
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_cliente_pago_estado();

GRANT EXECUTE ON FUNCTION public.asesor_confirmar_pago_credito(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.asesor_rechazar_pago_credito(uuid, text) TO authenticated;
