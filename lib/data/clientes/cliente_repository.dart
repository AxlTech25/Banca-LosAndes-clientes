import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../core/utils/currency_formatter.dart';

class CreditoModel {
  const CreditoModel({
    required this.id,
    this.producto,
    this.saldoActual,
    this.montoDesembolsado,
    this.cuotasPagadas = 0,
    this.cuotasTotal = 0,
    this.fechaVencimiento,
    this.diasMora = 0,
    this.estado = 'vigente',
    this.tea,
    this.plazoMeses,
  });

  factory CreditoModel.fromMap(Map<String, dynamic> map) {
    return CreditoModel(
      id: map['id']?.toString() ?? '',
      producto: map['producto']?.toString(),
      saldoActual: _asNum(map['saldo_actual']),
      montoDesembolsado: _asNum(map['monto_desembolsado']),
      cuotasPagadas: _asInt(map['cuotas_pagadas']),
      cuotasTotal: _asInt(map['cuotas_total']),
      fechaVencimiento: map['fecha_vencimiento']?.toString(),
      diasMora: _asInt(map['dias_mora']),
      estado: map['estado']?.toString() ?? 'vigente',
      tea: _asNum(map['tea']),
      plazoMeses: _asIntOrNull(map['plazo_meses']),
    );
  }

  final String id;
  final String? producto;
  final num? saldoActual;
  final num? montoDesembolsado;
  final int cuotasPagadas;
  final int cuotasTotal;
  final String? fechaVencimiento;
  final int diasMora;
  final String estado;
  final num? tea;
  final int? plazoMeses;

  bool get isVigente => estado == 'vigente';
  bool get enMora => diasMora > 0;

  int get cuotasRestantes =>
      (cuotasTotal - cuotasPagadas).clamp(0, cuotasTotal);

  num get cuotaEstimada {
    if (saldoActual == null || cuotasRestantes <= 0) return saldoActual ?? 0;
    return saldoActual! / cuotasRestantes;
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}

class ClienteRepository {
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

  Future<List<CreditoModel>> fetchCreditos() async {
    try {
      final rows = await _client
          .from('creditos')
          .select(
            'id, producto, saldo_actual, cuotas_pagadas, cuotas_total, '
            'fecha_vencimiento, dias_mora, estado, monto_desembolsado, tea, plazo_meses',
          )
          .order('created_at', ascending: false);
      return rows.map(CreditoModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<CreditoModel?> fetchCreditoVigente() async {
    try {
      final row = await _client
          .from('creditos')
          .select(
            'id, producto, saldo_actual, cuotas_pagadas, cuotas_total, '
            'fecha_vencimiento, dias_mora, estado, monto_desembolsado, tea, plazo_meses',
          )
          .eq('estado', 'vigente')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : CreditoModel.fromMap(row);
    } on PostgrestException {
      return null;
    }
  }

  Future<CreditoModel?> fetchCreditoById(String id) async {
    try {
      final row = await _client
          .from('creditos')
          .select(
            'id, producto, saldo_actual, cuotas_pagadas, cuotas_total, '
            'fecha_vencimiento, dias_mora, estado, monto_desembolsado, tea, plazo_meses',
          )
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : CreditoModel.fromMap(row);
    } on PostgrestException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPagosCredito(String creditoId) async {
    try {
      return await _client
          .from('pagos_credito')
          .select(
            'id, monto, tipo, metodo_pago, estado, referencia, created_at',
          )
          .eq('credito_id', creditoId)
          .order('created_at', ascending: false);
    } on PostgrestException {
      return [];
    }
  }

  Future<String?> registrarPagoCredito({
    required String creditoId,
    required double monto,
    required String metodoPago,
    String tipo = 'cuota',
  }) async {
    try {
      final pagoId = await _client.rpc(
        'registrar_pago_credito',
        params: {
          'p_credito_id': creditoId,
          'p_monto': monto,
          'p_metodo_pago': metodoPago,
          'p_tipo': tipo,
        },
      );
      return pagoId?.toString();
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<String?> confirmarPagoCredito(String pagoId) async {
    try {
      final id = await _client.rpc(
        'confirmar_pago_credito',
        params: {'p_pago_id': pagoId},
      );
      return id?.toString();
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<String?> registrarPagoSimulado({
    required String creditoId,
    required double monto,
  }) async {
    try {
      final pagoId = await _client.rpc(
        'registrar_pago_simulado',
        params: {
          'p_credito_id': creditoId,
          'p_monto': monto,
          'p_tipo': 'cuota',
        },
      );
      return pagoId?.toString();
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> updateContacto({
    String? email,
    String? telefono,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Sesion no valida.');

    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (email != null) payload['email'] = email.trim();
    if (telefono != null) payload['telefono'] = telefono.trim();

    try {
      await _client.from('clientes').update(payload).eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  static String formatBalance(num? amount) => CurrencyFormatter.pen(amount);

  static String buildNextPaymentLabel(CreditoModel? credito) {
    if (credito == null) return 'Sin credito activo';
    if (credito.enMora) {
      return 'En mora: ${credito.diasMora} dia${credito.diasMora == 1 ? '' : 's'}';
    }

    final vencimiento = credito.fechaVencimiento;
    if (vencimiento == null || vencimiento.isEmpty) {
      return 'Proximo pago por confirmar';
    }

    final fecha = DateTime.tryParse(vencimiento);
    if (fecha == null) return 'Proximo pago: $vencimiento';

    final diff = fecha.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Vencido hace ${diff.abs()} dias';
    if (diff == 0) return 'Proximo pago hoy';
    return 'Proximo pago en $diff dias';
  }
}
