import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/movimiento_cuenta_model.dart';
import '../../viewmodels/cuenta_view_model.dart';
import 'deposito_sheet.dart';
import 'transferencia_sheet.dart';

class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key, this.viewModel});

  final CuentaViewModel? viewModel;

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  late final CuentaViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? CuentaViewModel();
    _viewModel.startListening();
    _viewModel.load();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _depositar() async {
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDepositoSheet(context, _viewModel);
    if (!saved || !mounted) return;

    await _viewModel.refresh();
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _viewModel.error ?? 'Deposito registrado.',
        ),
      ),
    );
  }

  Future<void> _transferir() async {
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showTransferenciaSheet(context, _viewModel);
    if (!saved || !mounted) return;

    await _viewModel.refresh();
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _viewModel.error ?? 'Transferencia realizada.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.movimientos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _SaldoCard(viewModel: _viewModel),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _depositar,
                        icon: const Icon(Icons.add),
                        label: const Text('Depositar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _transferir,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Transferir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'MOVIMIENTOS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_viewModel.movimientos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Aun no tienes movimientos en tu cuenta.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._viewModel.movimientos.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MovimientoTile(movimiento: m),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.viewModel});

  final CuentaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuenta ${viewModel.numeroCuenta}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Saldo disponible',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
            Text(
              viewModel.saldo,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento});

  final MovimientoCuentaModel movimiento;

  @override
  Widget build(BuildContext context) {
    final ingreso = movimiento.esIngreso;
    final fecha = DateTime.tryParse(movimiento.createdAt ?? '');
    final fechaLabel = fecha != null ? _formatFecha(fecha.toLocal()) : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ingreso
              ? AppColors.primaryContainer
              : AppColors.errorContainer,
          child: Icon(
            ingreso ? Icons.arrow_downward : Icons.arrow_upward,
            color: ingreso ? AppColors.primary : AppColors.error,
            size: 20,
          ),
        ),
        title: Text(movimiento.concepto ?? movimiento.tipoLabel),
        subtitle: Text(
          [
            movimiento.tipoLabel,
            if (movimiento.cuentaDestino != null)
              'Cuenta: ${movimiento.cuentaDestino}',
            if (fechaLabel.isNotEmpty) fechaLabel,
          ].join(' · '),
        ),
        trailing: Text(
          '${ingreso ? '+' : '-'}${CurrencyFormatter.pen(movimiento.monto)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ingreso ? AppColors.primary : AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _formatFecha(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
