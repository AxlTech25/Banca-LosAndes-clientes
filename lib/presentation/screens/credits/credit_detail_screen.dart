import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../domain/models/fase4_models.dart';
import '../../viewmodels/credits_view_model.dart';
import '../../widgets/primary_action_button.dart';
import 'pago_credito_flow.dart';

class CreditDetailScreen extends StatefulWidget {
  const CreditDetailScreen({
    super.key,
    required this.creditoId,
    this.onPaymentComplete,
    this.creditsViewModel,
  });

  final String creditoId;
  final VoidCallback? onPaymentComplete;
  final CreditsViewModel? creditsViewModel;

  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen> {
  late final CreditsViewModel _viewModel;
  late final bool _ownsViewModel;
  final _clienteRepository = ClienteRepository();

  CreditoModel? _credito;
  List<PagoCreditoModel> _pagos = [];
  bool _isLoading = true;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.creditsViewModel == null;
    _viewModel = widget.creditsViewModel ?? CreditsViewModel();
    _load();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final credito = await _clienteRepository.fetchCreditoById(widget.creditoId);
    final pagosRaw = await _clienteRepository.fetchPagosCredito(widget.creditoId);
    if (!mounted) return;
    setState(() {
      _credito = credito;
      _pagos = pagosRaw.map(PagoCreditoModel.fromMap).toList();
      _isLoading = false;
    });
  }

  Future<void> _pagarCuota() async {
    final credito = _credito;
    if (credito == null || !credito.isVigente || _isPaying) return;

    setState(() => _isPaying = true);
    final monto = credito.cuotaEstimada.toDouble();

    final ok = await ejecutarPagoCuota(
      context,
      viewModel: _viewModel,
      creditoId: credito.id,
      monto: monto,
      onComplete: () async {
        widget.onPaymentComplete?.call();
        await _viewModel.refreshCreditos();
        await _load();
      },
    );

    if (!mounted) return;
    setState(() => _isPaying = false);

    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _confirmarPagoPendiente(PagoCreditoModel pago) async {
    setState(() => _isPaying = true);
    final ok = await _viewModel.confirmarPagoPendiente(pago.id);
    if (!mounted) return;
    setState(() => _isPaying = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago confirmado.')),
      );
      widget.onPaymentComplete?.call();
      await _viewModel.refreshCreditos();
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error ?? 'Error al confirmar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _pagos.where((p) => p.pendiente).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del credito'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _credito == null
          ? const Center(child: Text('Credito no encontrado'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoCard(credito: _credito!),
                  if (pendientes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PendientesCard(
                      pagos: pendientes,
                      onConfirmar: _confirmarPagoPendiente,
                      isPaying: _isPaying,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_credito!.isVigente && (_credito!.saldoActual ?? 0) > 0)
                    PrimaryActionButton(
                      label: _isPaying
                          ? 'Procesando...'
                          : 'Pagar cuota (${ClienteRepository.formatBalance(_credito!.cuotaEstimada)})',
                      isLoading: _isPaying,
                      onPressed: _isPaying ? null : _pagarCuota,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'HISTORIAL DE PAGOS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_pagos.isEmpty)
                    Text(
                      'Aun no hay pagos registrados.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._pagos.map((p) => _PagoTile(pago: p)),
                ],
              ),
            ),
    );
  }
}

class _PendientesCard extends StatelessWidget {
  const _PendientesCard({
    required this.pagos,
    required this.onConfirmar,
    required this.isPaying,
  });

  final List<PagoCreditoModel> pagos;
  final void Function(PagoCreditoModel) onConfirmar;
  final bool isPaying;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pagos pendientes de confirmacion',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ...pagos.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ClienteRepository.formatBalance(p.monto)),
                subtitle: Text(
                  '${p.metodoPago.toUpperCase()} · ${p.referencia ?? ''}',
                ),
                trailing: FilledButton(
                  onPressed: isPaying ? null : () => onConfirmar(p),
                  child: const Text('Confirmar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PagoTile extends StatelessWidget {
  const _PagoTile({required this.pago});

  final PagoCreditoModel pago;

  @override
  Widget build(BuildContext context) {
    final icon = pago.confirmado ? Icons.check_circle : Icons.schedule;
    final color = pago.confirmado ? AppColors.primary : Colors.orange;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(ClienteRepository.formatBalance(pago.monto)),
      subtitle: Text(
        '${pago.metodoPago.toUpperCase()} · ${pago.estado} · ${pago.referencia ?? ''}',
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.credito});

  final CreditoModel credito;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              credito.producto ?? 'Credito',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _Row('Estado', credito.estado),
            _Row('Saldo actual', ClienteRepository.formatBalance(credito.saldoActual)),
            _Row(
              'Desembolsado',
              ClienteRepository.formatBalance(credito.montoDesembolsado),
            ),
            _Row('Cuotas', '${credito.cuotasPagadas} / ${credito.cuotasTotal}'),
            _Row('TEA', credito.tea != null ? '${credito.tea}%' : '-'),
            _Row(
              'Proximo pago',
              ClienteRepository.buildNextPaymentLabel(credito),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
