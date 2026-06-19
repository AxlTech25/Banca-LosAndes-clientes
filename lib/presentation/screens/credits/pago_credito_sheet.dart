import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../domain/models/fase4_models.dart';
import '../../viewmodels/credits_view_model.dart';

Future<Map<String, dynamic>?> showPagoCreditoSheet(
  BuildContext context, {
  required CreditsViewModel viewModel,
  required double monto,
}) {
  MetodoPagoCredito? selected = MetodoPagoCredito.yape;

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pagar cuota',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monto: ${CurrencyFormatter.pen(monto)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                ...MetodoPagoCredito.values.map(
                  (m) => RadioListTile<MetodoPagoCredito>(
                    value: m,
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v),
                    title: Text(m.label),
                    subtitle: Text(
                      m.instrucciones,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: selected == null || viewModel.isPaying
                      ? null
                      : () => Navigator.pop(context, {
                          'metodo': selected!.value,
                          'monto': monto,
                        }),
                  child: viewModel.isPaying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continuar al pago'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showPagoPendienteDialog(
  BuildContext context, {
  required String pagoId,
  required MetodoPagoCredito metodo,
  required double monto,
  required CreditsViewModel viewModel,
  required VoidCallback onConfirmed,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          return AlertDialog(
            title: Text('Pago con ${metodo.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Realiza el pago de ${ClienteRepository.formatBalance(monto)} '
                  'usando el siguiente medio:',
                ),
                const SizedBox(height: 12),
                Text(
                  metodo.instrucciones,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cuando completes el pago, confirma para aplicarlo a tu credito. '
                  'En produccion esto se confirmaria automaticamente via webhook.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: viewModel.isPaying
                    ? null
                    : () async {
                        final ok = await viewModel.confirmarPagoPendiente(pagoId);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (ok) onConfirmed();
                      },
                child: viewModel.isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ya pague — confirmar'),
              ),
            ],
          );
        },
      );
    },
  );
}
