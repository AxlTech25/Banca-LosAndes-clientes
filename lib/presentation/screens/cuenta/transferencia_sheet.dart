import 'package:flutter/material.dart';

import '../../viewmodels/cuenta_view_model.dart';
import '../../widgets/primary_action_button.dart';

Future<bool?> showTransferenciaSheet(
  BuildContext context,
  CuentaViewModel viewModel,
) {
  final cuentaController = TextEditingController();
  final montoController = TextEditingController();
  final conceptoController = TextEditingController(text: 'Transferencia');

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Transferencia simulada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo disponible: ${viewModel.saldo}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cuentaController,
                  decoration: const InputDecoration(
                    labelText: 'Numero de cuenta destino',
                    border: OutlineInputBorder(),
                    hintText: '001-45678901',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto (S/)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conceptoController,
                  decoration: const InputDecoration(
                    labelText: 'Concepto',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (viewModel.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryActionButton(
                  label: 'Transferir',
                  isLoading: viewModel.isSubmitting,
                  onPressed: viewModel.isSubmitting
                      ? null
                      : () async {
                          final monto = double.tryParse(
                            montoController.text.trim(),
                          );
                          if (monto == null || monto <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa un monto valido.'),
                              ),
                            );
                            return;
                          }
                          if (cuentaController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa la cuenta destino.'),
                              ),
                            );
                            return;
                          }

                          final ok = await viewModel.transferir(
                            cuentaDestino: cuentaController.text.trim(),
                            monto: monto,
                            concepto: conceptoController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, ok);
                        },
                ),
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    cuentaController.dispose();
    montoController.dispose();
    conceptoController.dispose();
  });
}
