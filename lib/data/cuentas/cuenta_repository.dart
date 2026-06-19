import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/movimiento_cuenta_model.dart';

class CuentaRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<Map<String, dynamic>?> fetchCuentaAhorros() async {
    try {
      return await _client
          .from('cuentas')
          .select('id, numero_cuenta, saldo_disponible, moneda, tipo')
          .eq('tipo', 'ahorros')
          .eq('activa', true)
          .maybeSingle();
    } on PostgrestException {
      return null;
    }
  }

  Future<List<MovimientoCuentaModel>> fetchMovimientos({int limit = 50}) async {
    try {
      final rows = await _client
          .from('movimientos_cuenta')
          .select(
            'id, tipo, monto, saldo_resultante, concepto, referencia, '
            'cuenta_destino, created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(MovimientoCuentaModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<String?> registrarDepositoSimulado({
    required double monto,
    String? concepto,
  }) async {
    try {
      final id = await _client.rpc(
        'registrar_deposito_simulado',
        params: {
          'p_monto': monto,
          'p_concepto': concepto ?? 'Deposito simulado',
        },
      );
      return id?.toString();
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<String?> registrarTransferenciaSimulada({
    required String numeroCuentaDestino,
    required double monto,
    String? concepto,
  }) async {
    try {
      final id = await _client.rpc(
        'registrar_transferencia_simulada',
        params: {
          'p_numero_cuenta_destino': numeroCuentaDestino.trim(),
          'p_monto': monto,
          'p_concepto': concepto ?? 'Transferencia',
        },
      );
      return id?.toString();
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }
}
