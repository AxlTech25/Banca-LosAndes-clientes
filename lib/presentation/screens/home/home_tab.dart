import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../viewmodels/dashboard_view_model.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.viewModel,
    this.onNavigateToTab,
    this.onOpenCredito,
    this.onOpenCuenta,
    this.onPagarCuota,
  });

  final DashboardViewModel viewModel;
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(String creditoId)? onOpenCredito;
  final VoidCallback? onOpenCuenta;
  final VoidCallback? onPagarCuota;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: viewModel.loadDashboard,
      child: Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GreetingSection(
                  greeting: viewModel.greeting,
                  customerName: viewModel.isInitialLoading
                      ? '...'
                      : viewModel.customerName,
                ),
                if (viewModel.enMora) ...[
                  const SizedBox(height: 16),
                  _MoraBanner(diasMora: viewModel.diasMora),
                ],
                const SizedBox(height: 24),
                _BalanceCard(
                  viewModel: viewModel,
                  onTap: onOpenCuenta,
                ),
                const SizedBox(height: 16),
                _QuickActions(onNavigateToTab: onNavigateToTab),
                if (viewModel.hasOfertas) ...[
                  const SizedBox(height: 24),
                  _OffersSection(
                    preaprobados: viewModel.preaprobados,
                    campanas: viewModel.campanas,
                    onSolicitar: () => onNavigateToTab?.call(2),
                  ),
                ],
                const SizedBox(height: 24),
                _CommitmentsSection(
                  viewModel: viewModel,
                  onOpenCredito: onOpenCredito,
                  onNavigateToCredits: () => onNavigateToTab?.call(1),
                  onPagarCuota: onPagarCuota,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoraBanner extends StatelessWidget {
  const _MoraBanner({required this.diasMora});

  final int diasMora;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tu credito tiene $diasMora dia${diasMora == 1 ? '' : 's'} de mora. '
                'Regulariza tu pago cuanto antes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onNavigateToTab});

  final void Function(int tabIndex)? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.payments_outlined,
            label: 'Mis creditos',
            onTap: () => onNavigateToTab?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionChip(
            icon: Icons.add_circle_outline,
            label: 'Solicitar',
            onTap: () => onNavigateToTab?.call(2),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffersSection extends StatelessWidget {
  const _OffersSection({
    required this.preaprobados,
    required this.campanas,
    this.onSolicitar,
  });

  final List<PreaprobadoModel> preaprobados;
  final List<CampanaModel> campanas;
  final VoidCallback? onSolicitar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OFERTAS PARA TI',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...preaprobados.map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OfferBanner(
              title: 'Credito preaprobado',
              subtitle: 'Hasta ${CurrencyFormatter.pen(o.montoMaximo)}',
              detail: o.plazoSugeridoMeses != null
                  ? 'Plazo sugerido: ${o.plazoSugeridoMeses} meses'
                  : null,
              gradient: const [Color(0xFF1B5E20), Color(0xFF43A047)],
              onTap: onSolicitar,
            ),
          ),
        ),
        ...campanas.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OfferBanner(
              title: c.tipoCampana ?? 'Campana especial',
              subtitle: c.montoOfertado != null
                  ? 'Monto: ${CurrencyFormatter.pen(c.montoOfertado)}'
                  : 'Consulta condiciones',
              detail: null,
              gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
              onTap: onSolicitar,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({
    required this.title,
    required this.subtitle,
    this.detail,
    required this.gradient,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? detail;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.greeting,
    required this.customerName,
  });

  final String greeting;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hola, $customerName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: AppColors.onPrimary, size: 36),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.viewModel, this.onTap});

  final DashboardViewModel viewModel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.accountName,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Saldo Disponible',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                viewModel.isInitialLoading
                    ? const SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        viewModel.availableBalance,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommitmentsSection extends StatelessWidget {
  const _CommitmentsSection({
    required this.viewModel,
    this.onOpenCredito,
    this.onNavigateToCredits,
    this.onPagarCuota,
  });

  final DashboardViewModel viewModel;
  final void Function(String creditoId)? onOpenCredito;
  final VoidCallback? onNavigateToCredits;
  final VoidCallback? onPagarCuota;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MIS COMPROMISOS',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: viewModel.hasCreditoActivo
                ? () {
                    final id = viewModel.creditoActivoId;
                    if (id != null) {
                      onOpenCredito?.call(id);
                    } else {
                      onNavigateToCredits?.call();
                    }
                  }
                : onNavigateToCredits,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: viewModel.enMora
                        ? AppColors.errorContainer
                        : viewModel.hasCreditoActivo
                        ? AppColors.primaryContainer
                        : AppColors.primaryFixed,
                    child: Icon(
                      Icons.payments_outlined,
                      color: viewModel.enMora
                          ? AppColors.onErrorContainer
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewModel.hasCreditoActivo
                              ? 'Credito Activo'
                              : 'Sin credito activo',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          viewModel.nextPaymentLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: viewModel.enMora
                                ? AppColors.error
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (viewModel.hasCreditoActivo)
                          Text(
                            'Cuota mensual: ${viewModel.cuotaPagoLabel}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (viewModel.hasCreditoActivo)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          viewModel.canPagarCuota ? 'Proxima cuota' : 'Saldo',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          viewModel.pendingAmount,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: viewModel.enMora
                                ? AppColors.error
                                : AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (viewModel.hasCreditoActivo) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (viewModel.canPagarCuota) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPagarCuota,
            icon: const Icon(Icons.payments_outlined),
            label: Text('Pagar cuota ${viewModel.cuotaPagoLabel}'),
          ),
        ],
      ],
    );
  }
}
