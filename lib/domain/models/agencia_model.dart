class AgenciaModel {
  const AgenciaModel({
    required this.id,
    required this.nombre,
    this.region,
    this.lat,
    this.lng,
  });

  factory AgenciaModel.fromMap(Map<String, dynamic> map) {
    return AgenciaModel(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      region: map['region']?.toString(),
      lat: _asNum(map['lat']),
      lng: _asNum(map['lng']),
    );
  }

  final String id;
  final String nombre;
  final String? region;
  final num? lat;
  final num? lng;

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
