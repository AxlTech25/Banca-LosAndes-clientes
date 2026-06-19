class MovimientoCuentaModel {
  const MovimientoCuentaModel({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.saldoResultante,
    this.concepto,
    this.referencia,
    this.cuentaDestino,
    this.createdAt,
  });

  factory MovimientoCuentaModel.fromMap(Map<String, dynamic> map) {
    return MovimientoCuentaModel(
      id: map['id']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      monto: _asNum(map['monto']) ?? 0,
      saldoResultante: _asNum(map['saldo_resultante']) ?? 0,
      concepto: map['concepto']?.toString(),
      referencia: map['referencia']?.toString(),
      cuentaDestino: map['cuenta_destino']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  final String id;
  final String tipo;
  final num monto;
  final num saldoResultante;
  final String? concepto;
  final String? referencia;
  final String? cuentaDestino;
  final String? createdAt;

  bool get esIngreso =>
      tipo == 'deposito' || tipo == 'transferencia_entrada';

  String get tipoLabel => labelForTipo(tipo);

  static String labelForTipo(String tipo) {
    return switch (tipo) {
      'deposito' => 'Deposito',
      'transferencia_salida' => 'Transferencia enviada',
      'transferencia_entrada' => 'Transferencia recibida',
      'pago_credito' => 'Pago de credito',
      'ajuste' => 'Ajuste',
      _ => tipo,
    };
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
