import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../agencias/agencias_screen.dart';
import '../asesor/mi_asesor_screen.dart';
import '../buro/buro_resumido_screen.dart';
import '../cuenta/cuenta_screen.dart';
import '../../viewmodels/profile_view_model.dart';
import 'change_password_sheet.dart';
import 'edit_contact_sheet.dart';
import 'edit_negocio_sheet.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadProfile();
  }

  Future<void> _openCuenta() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CuentaScreen()),
    );
    if (!mounted) return;
    await widget.viewModel.loadProfile();
  }

  void _openBuro() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BuroResumidoScreen()),
    );
  }

  void _openAgencias() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgenciasScreen()),
    );
  }

  void _openMiAsesor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MiAsesorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        if (widget.viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: widget.viewModel.loadProfile,
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        widget.viewModel.fullName.isNotEmpty
                            ? widget.viewModel.fullName[0].toUpperCase()
                            : 'C',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.viewModel.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Contacto',
                      trailing: TextButton.icon(
                        onPressed: () =>
                            showEditContactSheet(context, widget.viewModel),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      children: [
                        _Tile(
                          Icons.badge_outlined,
                          'DNI',
                          widget.viewModel.dni,
                        ),
                        _Tile(
                          Icons.email_outlined,
                          'Email',
                          widget.viewModel.email,
                        ),
                        _Tile(
                          Icons.phone_outlined,
                          'Telefono',
                          widget.viewModel.telefono,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Mi negocio',
                      trailing: TextButton.icon(
                        onPressed: () =>
                            showEditNegocioSheet(context, widget.viewModel),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      children: [
                        if (!widget.viewModel.tienePerfilNegocio)
                          Text(
                            'Sin datos de negocio registrados. Toca Editar para completarlos.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        else ...[
                          _Tile(
                            Icons.storefront_outlined,
                            'Negocio',
                            widget.viewModel.nombreNegocio ?? '-',
                          ),
                          _Tile(
                            Icons.category_outlined,
                            'Tipo',
                            widget.viewModel.tipoNegocio ?? '-',
                          ),
                          _Tile(
                            Icons.location_on_outlined,
                            'Ubicacion',
                            widget.viewModel.ubicacionNegocio ?? '-',
                          ),
                          _Tile(
                            Icons.schedule_outlined,
                            'Antiguedad',
                            '${widget.viewModel.antiguedadNegocioMeses ?? '-'} meses',
                          ),
                          _Tile(
                            Icons.trending_up_outlined,
                            'Ingresos mensuales',
                            widget.viewModel.ingresosEstimados,
                          ),
                          _Tile(
                            Icons.payments_outlined,
                            'Gastos mensuales',
                            widget.viewModel.gastosMensuales,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Mi cuenta',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(widget.viewModel.numeroCuenta),
                          subtitle: Text('Saldo: ${widget.viewModel.saldoCuenta}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openCuenta,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Crediticio',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.analytics_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Calificacion SBS'),
                          subtitle: Text(
                            widget.viewModel.calificacionSbs ?? 'Ver detalle',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openBuro,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Seguridad',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.lock_outline, color: AppColors.primary),
                          title: const Text('Cambiar contrasena'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showChangePasswordSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Atencion',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.support_agent_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Mi asesor'),
                          subtitle: const Text('Datos de tu asesor de negocios'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openMiAsesor,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.store_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text('Agencias y sucursales'),
                          subtitle: const Text('Encuentra la oficina mas cercana'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openAgencias,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    this.title,
    this.trailing,
    required this.children,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
