-- Campos adicionales solicitud app clientes (producto, ubicacion) + telefono en registro

ALTER TABLE public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS producto varchar(60),
  ADD COLUMN IF NOT EXISTS ubicacion_negocio varchar(100);

CREATE OR REPLACE FUNCTION public.vincular_cliente_registro(
  p_dni text,
  p_nombres text,
  p_apellidos text,
  p_email text DEFAULT NULL,
  p_telefono text DEFAULT NULL
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
      telefono = COALESCE(NULLIF(trim(p_telefono), ''), telefono),
      updated_at = now()
    WHERE id = v_cliente_id;
  ELSE
    INSERT INTO public.clientes (
      user_id,
      numero_documento,
      tipo_documento,
      nombres,
      apellidos,
      email,
      telefono
    )
    VALUES (
      v_user_id,
      p_dni,
      'DNI',
      p_nombres,
      p_apellidos,
      NULLIF(trim(p_email), ''),
      NULLIF(trim(p_telefono), '')
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

GRANT EXECUTE ON FUNCTION public.vincular_cliente_registro(text, text, text, text, text)
  TO authenticated;
