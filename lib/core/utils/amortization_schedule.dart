import 'dart:math' as math;

import 'credit_calculator.dart';

class CuotaCronograma {
  const CuotaCronograma({
    required this.numero,
    required this.fechaPago,
    required this.cuota,
    required this.capital,
    required this.interes,
    required this.saldo,
  });

  final int numero;
  final DateTime fechaPago;
  final double cuota;
  final double capital;
  final double interes;
  final double saldo;
}

abstract final class AmortizationSchedule {
  /// Dia fijo de pago mensual (caso negocio: 15 de cada mes).
  static const diaPagoMensual = 15;

  /// Primera cuota: mes siguiente al desembolso, dia [diaPagoMensual].
  static DateTime primeraFechaPago(DateTime fechaDesembolso) {
    var year = fechaDesembolso.year;
    var month = fechaDesembolso.month + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, diaPagoMensual.clamp(1, lastDay));
  }

  static List<CuotaCronograma> generarFrances({
    required double monto,
    required int plazoMeses,
    required double teaPercent,
    DateTime? fechaDesembolso,
  }) {
    if (monto <= 0 || plazoMeses <= 0) return [];

    final desembolso = fechaDesembolso ?? DateTime.now();
    final cuotaFija = CreditCalculator.cuotaFrancesa(
      monto: monto,
      plazoMeses: plazoMeses,
      teaPercent: teaPercent,
    );
    final tem = CreditCalculator.temFromTeaPercent(teaPercent);

    var saldo = monto;
    var fecha = primeraFechaPago(desembolso);
    final rows = <CuotaCronograma>[];

    for (var n = 1; n <= plazoMeses; n++) {
      final interes = saldo * tem;
      var capital = cuotaFija - interes;
      if (n == plazoMeses) {
        capital = saldo;
      }
      saldo = math.max(0, saldo - capital);
      final cuota = n == plazoMeses ? capital + interes : cuotaFija;

      rows.add(
        CuotaCronograma(
          numero: n,
          fechaPago: fecha,
          cuota: _round2(cuota),
          capital: _round2(capital),
          interes: _round2(interes),
          saldo: _round2(saldo),
        ),
      );

      var nextMonth = fecha.month + 1;
      var nextYear = fecha.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
      fecha = DateTime(
        nextYear,
        nextMonth,
        diaPagoMensual.clamp(1, lastDay),
      );
    }

    return rows;
  }

  static double _round2(double value) =>
      double.parse(value.toStringAsFixed(2));
}
