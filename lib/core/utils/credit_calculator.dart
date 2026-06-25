import 'dart:math' as math;

abstract final class CreditCalculator {
  /// Tasa efectiva mensual: TEM = (1 + TEA)^(1/12) - 1
  static double temFromTeaPercent(double teaPercent) {
    final tea = teaPercent / 100;
    return math.pow(1 + tea, 1 / 12).toDouble() - 1;
  }

  /// Cuota fija (amortizacion francesa).
  static double cuotaFrancesa({
    required double monto,
    required int plazoMeses,
    required double teaPercent,
  }) {
    if (monto <= 0 || plazoMeses <= 0) return 0;
    final tem = temFromTeaPercent(teaPercent);
    if (tem <= 0) return monto / plazoMeses;

    final factor = math.pow(1 + tem, plazoMeses).toDouble();
    return monto * tem * factor / (factor - 1);
  }
}
