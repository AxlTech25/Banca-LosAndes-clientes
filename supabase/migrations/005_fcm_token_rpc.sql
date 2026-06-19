-- Guardar token FCM del dispositivo en el perfil del cliente

CREATE OR REPLACE FUNCTION public.guardar_token_fcm(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion';
  END IF;

  UPDATE public.clientes
  SET
    token_fcm = NULLIF(trim(p_token), ''),
    updated_at = now()
  WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cliente no encontrado';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.guardar_token_fcm(text) TO authenticated;

-- Helper para Edge Function: obtener token FCM de un cliente
CREATE OR REPLACE FUNCTION public.obtener_token_fcm_cliente(p_cliente_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT token_fcm FROM public.clientes WHERE id = p_cliente_id LIMIT 1;
$$;

-- Solo service_role debe invocar esto desde Edge Functions
REVOKE ALL ON FUNCTION public.obtener_token_fcm_cliente(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obtener_token_fcm_cliente(uuid) TO service_role;
