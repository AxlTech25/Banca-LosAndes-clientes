import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../viewmodels/request_credit_view_model.dart';
import '../../widgets/primary_action_button.dart';
import 'new_solicitud_screen.dart';
import 'solicitud_detail_screen.dart';

class RequestTab extends StatefulWidget {
  const RequestTab({super.key, required this.viewModel});

  final RequestCreditViewModel viewModel;

  @override
  State<RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends State<RequestTab> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  Future<void> _openNewSolicitud({NuevaSolicitudInput? prefilled}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewSolicitudScreen(
          viewModel: widget.viewModel,
          prefilled: prefilled,
        ),
      ),
    );
    if (created == true) await widget.viewModel.load();
  }

  Future<void> _openDetail(SolicitudModel solicitud) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitudDetailScreen(solicitudId: solicitud.id),
      ),
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
          onRefresh: widget.viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              PrimaryActionButton(
                label: 'Nueva solicitud de credito',
                onPressed: () => _openNewSolicitud(),
              ),
              if (widget.viewModel.preaprobados.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionTitle('Ofertas preaprobadas'),
                const SizedBox(height: 8),
                ...widget.viewModel.preaprobados.map(
                  (o) => _OfertaCard(
                    title: 'Preaprobado hasta ${ClienteRepository.formatBalance(o.montoMaximo)}',
                    subtitle:
                        'Plazo sugerido: ${o.plazoSugeridoMeses ?? '-'} meses',
                    onTap: () => _openNewSolicitud(
                      prefilled: NuevaSolicitudInput(
                        tipoNegocio: widget.viewModel.clienteTipoNegocio ?? 'Comercio',
                        nombreNegocio: widget.viewModel.clienteNombreNegocio ?? '',
                        antiguedadMeses: widget.viewModel.clienteAntiguedadMeses ?? 12,
                        ingresosEstimados: widget.viewModel.clienteIngresos ?? 2000,
                        montoSolicitado: (o.montoMaximo ?? 0).toDouble(),
                        plazoMeses: o.plazoSugeridoMeses ?? 12,
                        destinoCredito: 'Capital de trabajo',
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.viewModel.campanas.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionTitle('Campanas activas'),
                const SizedBox(height: 8),
                ...widget.viewModel.campanas.map(
                  (c) => _OfertaCard(
                    title: c.tipoCampana ?? 'Campana',
                    subtitle:
                        'Monto: ${ClienteRepository.formatBalance(c.montoOfertado)}',
                    onTap: () => _openNewSolicitud(
                      prefilled: NuevaSolicitudInput(
                        tipoNegocio: widget.viewModel.clienteTipoNegocio ?? 'Comercio',
                        nombreNegocio: widget.viewModel.clienteNombreNegocio ?? '',
                        antiguedadMeses: widget.viewModel.clienteAntiguedadMeses ?? 12,
                        ingresosEstimados: widget.viewModel.clienteIngresos ?? 2000,
                        montoSolicitado: (c.montoOfertado ?? 0).toDouble(),
                        plazoMeses: 12,
                        destinoCredito: c.tipoCampana ?? 'Campana bancaria',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _SectionTitle('Mis solicitudes'),
              const SizedBox(height: 8),
              if (widget.viewModel.solicitudes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Aun no has enviado solicitudes. Tu asesor las revisara cuando envies una.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...widget.viewModel.solicitudes.map(
                  (s) => _SolicitudCard(
                    solicitud: s,
                    onTap: () => _openDetail(s),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _OfertaCard extends StatelessWidget {
  const _OfertaCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: Icon(Icons.local_offer_outlined, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({required this.solicitud, required this.onTap});

  final SolicitudModel solicitud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(solicitud.numeroExpediente ?? 'Solicitud'),
        subtitle: Text(
          '${solicitud.estadoLabel} · ${ClienteRepository.formatBalance(solicitud.montoSolicitado)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
