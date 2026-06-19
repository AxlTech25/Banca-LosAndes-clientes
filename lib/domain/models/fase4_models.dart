class MensajeSolicitudModel {
  const MensajeSolicitudModel({
    required this.id,
    required this.solicitudId,
    required this.autorTipo,
    required this.contenido,
    this.createdAt,
    this.esPropio = false,
  });

  factory MensajeSolicitudModel.fromMap(
    Map<String, dynamic> map, {
    String? currentClienteId,
  }) {
    final autor = map['autor_tipo']?.toString() ?? '';
    return MensajeSolicitudModel(
      id: map['id']?.toString() ?? '',
      solicitudId: map['solicitud_id']?.toString() ?? '',
      autorTipo: autor,
      contenido: map['contenido']?.toString() ?? '',
      createdAt: map['created_at']?.toString(),
      esPropio: autor == 'cliente',
    );
  }

  final String id;
  final String solicitudId;
  final String autorTipo;
  final String contenido;
  final String? createdAt;
  final bool esPropio;

  bool get esAsesor => autorTipo == 'asesor';
}

class BuroResumidoModel {
  const BuroResumidoModel({
    this.calificacionSbs,
    this.entidadesConDeuda,
    this.fechaUltimaConsulta,
    this.descripcion,
  });

  factory BuroResumidoModel.fromMap(Map<String, dynamic> map) {
    return BuroResumidoModel(
      calificacionSbs: map['calificacion_sbs']?.toString(),
      entidadesConDeuda: _asIntOrNull(map['entidades_con_deuda']),
      fechaUltimaConsulta: map['fecha_ultima_consulta']?.toString(),
      descripcion: map['descripcion']?.toString(),
    );
  }

  final String? calificacionSbs;
  final int? entidadesConDeuda;
  final String? fechaUltimaConsulta;
  final String? descripcion;

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get calificacionLabel => calificacionSbs ?? 'Sin calificar';

  String get nivelColorKey => switch (calificacionSbs) {
    'Normal' => 'normal',
    'CPP' => 'cpp',
    'Deficiente' => 'deficiente',
    'Dudoso' => 'dudoso',
    'Pérdida' => 'perdida',
    _ => 'neutral',
  };
}

enum MetodoPagoCredito {
  yape('yape', 'Yape', 'Paga con el numero del banco: 999 888 777'),
  transferencia('transferencia', 'Transferencia', 'BCP · CCI: 002-123-4567890123456-01'),
  agente('agente', 'Agente / ventanilla', 'Presenta tu DNI en cualquier agencia Los Andes');

  const MetodoPagoCredito(this.value, this.label, this.instrucciones);

  final String value;
  final String label;
  final String instrucciones;
}

class PagoCreditoModel {
  const PagoCreditoModel({
    required this.id,
    required this.monto,
    required this.metodoPago,
    required this.estado,
    this.referencia,
    this.createdAt,
  });

  factory PagoCreditoModel.fromMap(Map<String, dynamic> map) {
    return PagoCreditoModel(
      id: map['id']?.toString() ?? '',
      monto: _asNum(map['monto']) ?? 0,
      metodoPago: map['metodo_pago']?.toString() ?? 'simulado',
      estado: map['estado']?.toString() ?? 'confirmado',
      referencia: map['referencia']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  final String id;
  final num monto;
  final String metodoPago;
  final String estado;
  final String? referencia;
  final String? createdAt;

  bool get pendiente => estado == 'pendiente';
  bool get confirmado => estado == 'confirmado';

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
