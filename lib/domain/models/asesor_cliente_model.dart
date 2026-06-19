class AsesorClienteModel {
  const AsesorClienteModel({
    required this.asesorId,
    required this.nombres,
    required this.apellidos,
    this.codigoEmpleado,
    this.agencia,
    this.region,
    this.origen,
  });

  factory AsesorClienteModel.fromMap(Map<String, dynamic> map) {
    return AsesorClienteModel(
      asesorId: map['asesor_id']?.toString() ?? '',
      nombres: map['nombres']?.toString() ?? '',
      apellidos: map['apellidos']?.toString() ?? '',
      codigoEmpleado: map['codigo_empleado']?.toString(),
      agencia: map['agencia']?.toString(),
      region: map['region']?.toString(),
      origen: map['origen']?.toString(),
    );
  }

  final String asesorId;
  final String nombres;
  final String apellidos;
  final String? codigoEmpleado;
  final String? agencia;
  final String? region;
  final String? origen;

  String get nombreCompleto =>
      [nombres, apellidos].where((p) => p.isNotEmpty).join(' ');

  String get origenLabel => switch (origen) {
    'credito' => 'Asignado por tu credito',
    'solicitud' => 'Asignado por tu solicitud',
    _ => 'Tu asesor de negocios',
  };
}
