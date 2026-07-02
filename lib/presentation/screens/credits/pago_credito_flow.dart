import 'package:flutter/material.dart';

import '../../../domain/models/fase4_models.dart';
import '../../viewmodels/credits_view_model.dart';
import 'pago_credito_sheet.dart';

/// Flujo reutilizable de pago de cuota (Inicio y detalle de credito).
Future<bool> ejecutarPagoCuota(
  BuildContext context, {
  required CreditsViewModel viewModel,
  required String creditoId,
  required double monto,
  VoidCallback? onComplete,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final selection = await showPagoCreditoSheet(
    context,
    monto: monto,
  );
  if (selection == null || !context.mounted) return false;

  final metodo = selection['metodo'] as String;
  final pagoId = await viewModel.pagarCuota(
    creditoId: creditoId,
    monto: monto,
    metodoPago: metodo,
  );

  if (!context.mounted) return false;

  if (pagoId == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(viewModel.error ?? 'No se pudo registrar el pago.'),
      ),
    );
    return false;
  }

  final metodoEnum = MetodoPagoCredito.values.firstWhere(
    (m) => m.value == metodo,
  );

  var confirmed = false;
  await showPagoPendienteDialog(
    context,
    pagoId: pagoId,
    metodo: metodoEnum,
    monto: monto,
    viewModel: viewModel,
    onConfirmed: () {
      confirmed = true;
      onComplete?.call();
    },
  );

  if (context.mounted && confirmed) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Pago confirmado y aplicado a tu credito.')),
    );
  }

  return confirmed;
}
