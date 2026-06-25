-- Perfil de negocio en registro (gastos mensuales) + evitar documentos duplicados por tipo

ALTER TABLE public.clientes
  ADD COLUMN IF NOT EXISTS gastos_mensuales numeric;

CREATE OR REPLACE FUNCTION public.actualizar_perfil_negocio_cliente(
  p_tipo_negocio text,
  p_nombre_negocio text,
  p_ubicacion_negocio text,
  p_antiguedad_meses integer,
  p_ingresos_estimados numeric,
  p_gastos_mensuales numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion';
  END IF;

  p_tipo_negocio := trim(p_tipo_negocio);
  p_nombre_negocio := trim(p_nombre_negocio);
  p_ubicacion_negocio := trim(p_ubicacion_negocio);

  IF length(p_tipo_negocio) = 0 OR length(p_nombre_negocio) = 0 OR length(p_ubicacion_negocio) = 0 THEN
    RAISE EXCEPTION 'Completa los datos de tu negocio';
  END IF;

  IF coalesce(p_antiguedad_meses, 0) <= 0 THEN
    RAISE EXCEPTION 'La antiguedad del negocio debe ser mayor a 0';
  END IF;

  IF coalesce(p_ingresos_estimados, 0) <= 0 OR coalesce(p_gastos_mensuales, 0) <= 0 THEN
    RAISE EXCEPTION 'Ingresos y gastos deben ser mayores a 0';
  END IF;

  UPDATE public.clientes
  SET
    tipo_negocio = p_tipo_negocio,
    nombre_negocio = p_nombre_negocio,
    direccion = p_ubicacion_negocio,
    antiguedad_negocio_meses = p_antiguedad_meses,
    ingresos_estimados = p_ingresos_estimados,
    gastos_mensuales = p_gastos_mensuales,
    updated_at = now()
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro tu perfil de cliente';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.actualizar_perfil_negocio_cliente(
  text, text, text, integer, numeric, numeric
) TO authenticated;

-- Un solo documento activo por tipo y solicitud
DELETE FROM public.solicitudes_documentos d
USING public.solicitudes_documentos d2
WHERE d.solicitud_id = d2.solicitud_id
  AND d.tipo_documento = d2.tipo_documento
  AND d.created_at < d2.created_at;

CREATE UNIQUE INDEX IF NOT EXISTS idx_solicitudes_documentos_solicitud_tipo
  ON public.solicitudes_documentos (solicitud_id, tipo_documento);
