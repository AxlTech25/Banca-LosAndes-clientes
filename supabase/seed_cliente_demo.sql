-- =============================================================================
-- App Clientes — datos de prueba (BD compartida con Fuerza de Ventas)
-- PREREQUISITOS:
--   1. Schema operadores: appbanco_losandes_ventas/supabase/seed_demo.sql
--   2. Migracion clientes: 001_app_clientes_schema.sql
-- =============================================================================

-- Cuentas de ahorros para clientes demo (sin user_id aun; se vinculan al registrarse)
INSERT INTO public.cuentas (cliente_id, numero_cuenta, tipo, moneda, saldo_disponible)
SELECT c.id, '001-' || c.numero_documento, 'ahorros', 'PEN', v.saldo
FROM public.clientes c
JOIN (VALUES
  ('12345678', 1250.00),
  ('45678901', 850.50),
  ('87654321', 0)
) AS v(dni, saldo) ON c.numero_documento = v.dni
WHERE NOT EXISTS (
  SELECT 1 FROM public.cuentas cu
  WHERE cu.cliente_id = c.id AND cu.tipo = 'ahorros' AND cu.activa = true
);

-- Actualizar credito vigente de Carlos con fecha de vencimiento proxima
UPDATE public.creditos
SET
  estado = 'vigente',
  fecha_vencimiento = current_date + interval '5 days',
  saldo_actual = 450.00,
  cuotas_total = 18,
  cuotas_pagadas = 11,
  dias_mora = 0
WHERE id = 'd4444444-4444-4444-8444-444444444402';

-- Campana activa para Carlos (prueba ofertas fase 2)
INSERT INTO public.campanas_activas (
  asesor_id, cliente_id, tipo_campana, monto_ofertado, activa, fecha_vencimiento
)
SELECT
  'b2222222-2222-4222-8222-222222222222',
  c.id,
  'Renovacion anticipada',
  5000.00,
  true,
  current_date + interval '15 days'
FROM public.clientes c
WHERE c.numero_documento = '12345678'
  AND NOT EXISTS (
    SELECT 1 FROM public.campanas_activas ca
    WHERE ca.cliente_id = c.id AND ca.activa = true
  );

-- Movimientos demo para Carlos (requiere migracion 007)
INSERT INTO public.movimientos_cuenta (
  cuenta_id, cliente_id, tipo, monto, saldo_resultante, concepto, referencia
)
SELECT
  cu.id,
  c.id,
  v.tipo,
  v.monto,
  v.saldo,
  v.concepto,
  v.referencia
FROM public.clientes c
JOIN public.cuentas cu ON cu.cliente_id = c.id AND cu.tipo = 'ahorros'
JOIN (VALUES
  ('deposito', 1250.00, 1250.00, 'Deposito inicial demo', 'DEP-DEMO-001')
) AS v(tipo, monto, saldo, concepto, referencia) ON true
WHERE c.numero_documento = '12345678'
  AND NOT EXISTS (
    SELECT 1 FROM public.movimientos_cuenta mc
    WHERE mc.cliente_id = c.id AND mc.referencia LIKE 'DEP-DEMO-%'
  );

-- =============================================================================
-- PRUEBA EN APP CLIENTES:
--   Registro/login DNI: 12345678  |  Nombre: Carlos Rojas
--   Al registrarse se vincula user_id y vera cuenta S/ 1250 + credito vigente
-- =============================================================================
