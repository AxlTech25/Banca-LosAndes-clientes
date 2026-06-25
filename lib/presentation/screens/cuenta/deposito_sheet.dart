import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/cuenta_view_model.dart';

Future<bool> showDepositoSheet(
  BuildContext context,
  CuentaViewModel viewModel,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _DepositoSheet(
        viewModel: viewModel,
        onSaved: () => Navigator.of(sheetContext).pop(true),
      );
    },
  ).then((value) => value ?? false);
}

class _DepositoSheet extends StatefulWidget {
  const _DepositoSheet({
    required this.viewModel,
    required this.onSaved,
  });

  final CuentaViewModel viewModel;
  final VoidCallback onSaved;

  @override
  State<_DepositoSheet> createState() => _DepositoSheetState();
}

class _DepositoSheetState extends State<_DepositoSheet> {
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController(text: 'Deposito simulado');

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _montoController.dispose();
    _conceptoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_montoController.text.trim());
    final concepto = _conceptoController.text.trim();

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final ok = await widget.viewModel.depositar(
      monto: monto,
      concepto: concepto.isEmpty ? null : concepto,
    );

    if (!mounted) return;

    if (ok) {
      widget.onSaved();
      return;
    }

    setState(() {
      _isSaving = false;
      _error = widget.viewModel.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Deposito simulado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto (S/)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conceptoController,
              decoration: const InputDecoration(
                labelText: 'Concepto',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _confirmar,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar deposito'),
            ),
          ],
        ),
      ),
    );
  }
}
