import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../viewmodels/credits_view_model.dart';
import 'credito_cronograma_screen.dart';
import 'credit_detail_screen.dart';

class CreditsTab extends StatefulWidget {
  const CreditsTab({
    super.key,
    required this.viewModel,
    this.onDataChanged,
  });

  final CreditsViewModel viewModel;
  final VoidCallback? onDataChanged;

  @override
  State<CreditsTab> createState() => _CreditsTabState();
}

class _CreditsTabState extends State<CreditsTab> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadCreditos();
  }

  Future<void> _openEntry(CreditoTabEntry entry) async {
    if (entry.kind == CreditoTabEntryKind.solicitudAprobada) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreditoCronogramaScreen(
            solicitudId: entry.solicitud!.id,
          ),
        ),
      );
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreditDetailScreen(
          creditoId: entry.credito!.id,
          creditsViewModel: widget.viewModel,
          onPaymentComplete: widget.onDataChanged,
        ),
      ),
    );
    if (changed == true) {
      await widget.viewModel.loadCreditos();
      widget.onDataChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        if (widget.viewModel.isLoading && widget.viewModel.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (widget.viewModel.isEmpty) {
          return RefreshIndicator(
            onRefresh: widget.viewModel.loadCreditos,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 64,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes creditos registrados',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cuando aprueben tu solicitud o tu asesor registre un credito, '
                            'aparecera aqui con el cronograma de pagos.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.viewModel.loadCreditos,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: widget.viewModel.entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = widget.viewModel.entries[index];
              if (entry.kind == CreditoTabEntryKind.solicitudAprobada) {
                return _SolicitudAprobadaCard(
                  solicitud: entry.solicitud!,
                  onTap: () => _openEntry(entry),
                );
              }
              return _CreditoCard(
                credito: entry.credito!,
                onTap: () => _openEntry(entry),
              );
            },
          ),
        );
      },
    );
  }
}

class _SolicitudAprobadaCard extends StatelessWidget {
  const _SolicitudAprobadaCard({
    required this.solicitud,
    required this.onTap,
  });

  final SolicitudModel solicitud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final monto = solicitud.montoAprobado ?? solicitud.montoSolicitado;
    final aprobada = solicitud.estado == 'aprobada';

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: aprobada
                  ? Colors.green.shade300
                  : AppColors.primaryContainer,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: aprobada
                    ? Colors.green.shade50
                    : AppColors.primaryContainer,
                child: Icon(
                  aprobada ? Icons.verified_outlined : Icons.account_balance,
                  color: aprobada ? Colors.green.shade700 : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.productoLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SolicitudModel.labelForEstado(solicitud.estado),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: aprobada
                            ? Colors.green.shade700
                            : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (solicitud.cuotaMensualMostrada != null)
                      Text(
                        'Cuota ${ClienteRepository.formatBalance(solicitud.cuotaMensualMostrada)} · '
                        '${solicitud.plazoMeses ?? '-'} cuotas',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      'Toca para ver cronograma',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ClienteRepository.formatBalance(monto),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditoCard extends StatelessWidget {
  const _CreditoCard({required this.credito, required this.onTap});

  final CreditoModel credito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enMora = credito.enMora;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: enMora
                    ? AppColors.errorContainer
                    : AppColors.primaryContainer,
                child: Icon(
                  Icons.account_balance,
                  color: enMora ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credito.producto ?? 'Credito',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ClienteRepository.buildNextPaymentLabel(credito),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${credito.cuotasPagadas}/${credito.cuotasTotal} cuotas',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ClienteRepository.formatBalance(credito.saldoActual),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enMora ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
