class SolicitudModel {
  const SolicitudModel({
    required this.id,
    this.numeroExpediente,
    this.estado,
    this.montoSolicitado,
    this.montoAprobado,
    this.plazoMeses,
    this.destinoCredito,
    this.nombreNegocio,
    this.tipoNegocio,
    this.motivoRechazo,
    this.condicionAdicional,
    this.createdAt,
    this.firmaClienteBase64,
  });

  factory SolicitudModel.fromMap(Map<String, dynamic> map) {
    return SolicitudModel(
      id: map['id']?.toString() ?? '',
      numeroExpediente: map['numero_expediente']?.toString(),
      estado: map['estado']?.toString() ?? 'borrador',
      montoSolicitado: _asNum(map['monto_solicitado']),
      montoAprobado: _asNum(map['monto_aprobado']),
      plazoMeses: _asIntOrNull(map['plazo_meses']),
      destinoCredito: map['destino_credito']?.toString(),
      nombreNegocio: map['nombre_negocio']?.toString(),
      tipoNegocio: map['tipo_negocio']?.toString(),
      motivoRechazo: map['motivo_rechazo']?.toString(),
      condicionAdicional: map['condicion_adicional']?.toString(),
      createdAt: map['created_at']?.toString(),
      firmaClienteBase64: map['firma_cliente_base64']?.toString(),
    );
  }

  final String id;
  final String? numeroExpediente;
  final String? estado;
  final num? montoSolicitado;
  final num? montoAprobado;
  final int? plazoMeses;
  final String? destinoCredito;
  final String? nombreNegocio;
  final String? tipoNegocio;
  final String? motivoRechazo;
  final String? condicionAdicional;
  final String? createdAt;
  final String? firmaClienteBase64;

  String get estadoLabel => labelForEstado(estado);

  bool get tieneFirma =>
      firmaClienteBase64 != null && firmaClienteBase64!.length > 50;

  bool get puedeSubirDocumentos =>
      estado == 'borrador' || estado == 'pendiente' || estado == 'observada';

  static String labelForEstado(String? estado) {
    return switch (estado) {
      'borrador' => 'Borrador',
      'pendiente' => 'En revision',
      'en_evaluacion' => 'En evaluacion',
      'observada' => 'Requiere documentos',
      'enviada' => 'Enviada',
      'aprobada' => 'Aprobada',
      'rechazada' => 'No aprobada',
      'desembolsada' => 'Desembolsada',
      _ => estado ?? 'Desconocido',
    };
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class HistorialEstadoModel {
  const HistorialEstadoModel({
    required this.estadoNuevo,
    this.estadoAnterior,
    this.observacion,
    this.actorTipo,
    this.createdAt,
  });

  factory HistorialEstadoModel.fromMap(Map<String, dynamic> map) {
    return HistorialEstadoModel(
      estadoNuevo: map['estado_nuevo']?.toString() ?? '',
      estadoAnterior: map['estado_anterior']?.toString(),
      observacion: map['observacion']?.toString(),
      actorTipo: map['actor_tipo']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  final String estadoNuevo;
  final String? estadoAnterior;
  final String? observacion;
  final String? actorTipo;
  final String? createdAt;

  String get estadoLabel => SolicitudModel.labelForEstado(estadoNuevo);
}

class PreaprobadoModel {
  const PreaprobadoModel({
    required this.id,
    this.montoMaximo,
    this.plazoSugeridoMeses,
    this.teaReferencial,
    this.fechaVencimiento,
  });

  factory PreaprobadoModel.fromMap(Map<String, dynamic> map) {
    return PreaprobadoModel(
      id: map['id']?.toString() ?? '',
      montoMaximo: SolicitudModel._asNum(map['monto_maximo']),
      plazoSugeridoMeses: SolicitudModel._asIntOrNull(map['plazo_sugerido_meses']),
      teaReferencial: SolicitudModel._asNum(map['tea_referencial']),
      fechaVencimiento: map['fecha_vencimiento']?.toString(),
    );
  }

  final String id;
  final num? montoMaximo;
  final int? plazoSugeridoMeses;
  final num? teaReferencial;
  final String? fechaVencimiento;
}

class CampanaModel {
  const CampanaModel({
    required this.id,
    this.tipoCampana,
    this.montoOfertado,
    this.fechaVencimiento,
  });

  factory CampanaModel.fromMap(Map<String, dynamic> map) {
    return CampanaModel(
      id: map['id']?.toString() ?? '',
      tipoCampana: map['tipo_campana']?.toString(),
      montoOfertado: SolicitudModel._asNum(map['monto_ofertado']),
      fechaVencimiento: map['fecha_vencimiento']?.toString(),
    );
  }

  final String id;
  final String? tipoCampana;
  final num? montoOfertado;
  final String? fechaVencimiento;
}

class NuevaSolicitudInput {
  const NuevaSolicitudInput({
    required this.tipoNegocio,
    required this.nombreNegocio,
    required this.antiguedadMeses,
    required this.ingresosEstimados,
    required this.montoSolicitado,
    required this.plazoMeses,
    required this.destinoCredito,
  });

  final String tipoNegocio;
  final String nombreNegocio;
  final int antiguedadMeses;
  final double ingresosEstimados;
  final double montoSolicitado;
  final int plazoMeses;
  final String destinoCredito;
}

class SolicitudDocumentoModel {
  const SolicitudDocumentoModel({
    required this.id,
    required this.tipoDocumento,
    this.storageUrl,
    this.tamanioKb,
    this.createdAt,
  });

  factory SolicitudDocumentoModel.fromMap(Map<String, dynamic> map) {
    return SolicitudDocumentoModel(
      id: map['id']?.toString() ?? '',
      tipoDocumento: map['tipo_documento']?.toString() ?? '',
      storageUrl: map['storage_url']?.toString(),
      tamanioKb: SolicitudModel._asIntOrNull(map['tamanio_kb']),
      createdAt: map['created_at']?.toString(),
    );
  }

  final String id;
  final String tipoDocumento;
  final String? storageUrl;
  final int? tamanioKb;
  final String? createdAt;

  String get tipoLabel => DocumentoTipos.label(tipoDocumento);
}

abstract final class DocumentoTipos {
  static const dniFrente = 'DNI_FRENTE';
  static const dniReverso = 'DNI_REVERSO';
  static const reciboServicios = 'RECIBO_SERVICIOS';
  static const fotoNegocio = 'FOTO_NEGOCIO';

  static const requeridos = [
    dniFrente,
    dniReverso,
    reciboServicios,
    fotoNegocio,
  ];

  static String label(String tipo) {
    return switch (tipo) {
      dniFrente => 'DNI (frente)',
      dniReverso => 'DNI (reverso)',
      reciboServicios => 'Recibo de servicios',
      fotoNegocio => 'Foto del negocio',
      _ => tipo,
    };
  }
}
