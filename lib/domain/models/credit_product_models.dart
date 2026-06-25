abstract final class CreditoProducto {
  static const codigo = 'credito_empresarial_micro';
  static const nombre = 'Credito Empresarial — Microempresa';
  static const teaConDesgravamen = 40.92;
  static const teaSinDesgravamen = 43.92;
}

abstract final class GarantiaTipos {
  static const sinGarantia = 'sin_garantia';
  static const prendaria = 'prendaria';
  static const hipotecaria = 'hipotecaria';
  static const vehicular = 'vehicular';

  static const opciones = <String, String>{
    sinGarantia: 'Sin garantia',
    prendaria: 'Prendaria',
    hipotecaria: 'Hipotecaria',
    vehicular: 'Vehicular',
  };

  static String label(String? code) {
    if (code == null || code.isEmpty) return '-';
    return opciones[code] ?? code;
  }
}
