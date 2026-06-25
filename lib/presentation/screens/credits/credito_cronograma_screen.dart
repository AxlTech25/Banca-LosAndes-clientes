import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../data/solicitudes/solicitud_repository.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../widgets/cronograma_pagos_section.dart';

class CreditoCronogramaScreen extends StatefulWidget {
  const CreditoCronogramaScreen({super.key, required this.solicitudId});

  final String solicitudId;

  @override
  State<CreditoCronogramaScreen> createState() => _CreditoCronogramaScreenState();
}

class _CreditoCronogramaScreenState extends State<CreditoCronogramaScreen> {
  final _repository = SolicitudRepository();

  SolicitudModel? _solicitud;
  List<CronogramaCuotaModel> _cronograma = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final solicitud = await _repository.fetchSolicitudById(widget.solicitudId);
    List<CronogramaCuotaModel> cronograma = [];
    if (solicitud != null && solicitud.muestraCronograma) {
      cronograma = await _repository.fetchCronograma(solicitud);
    }
    if (!mounted) return;
    setState(() {
      _solicitud = solicitud;
      _cronograma = cronograma;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _solicitud;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi credito'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : solicitud == null
          ? const Center(child: Text('Credito no encontrado'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ResumenCard(solicitud: solicitud),
                  const SizedBox(height: 16),
                  CronogramaPagosSection(
                    cuotas: _cronograma,
                    cuotaMensual: solicitud.cuotaMensualMostrada,
                    fechaDesembolsoProgramada: solicitud.fechaDesembolsoProgramada,
                    descripcion: solicitud.estado == 'desembolsada'
                        ? 'Cronograma de cuotas de tu credito desembolsado.'
                        : 'Tu credito fue aprobado. Estas son las cuotas mensuales '
                              '(amortizacion francesa, pagos el dia 15 de cada mes).',
                  ),
                  if (_cronograma.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'El cronograma se generara cuando se confirme la aprobacion.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({required this.solicitud});

  final SolicitudModel solicitud;

  @override
  Widget build(BuildContext context) {
    final monto = solicitud.montoAprobado ?? solicitud.montoSolicitado;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    solicitud.productoLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _EstadoChip(estado: solicitud.estado),
              ],
            ),
            if (solicitud.numeroExpediente != null) ...[
              const SizedBox(height: 4),
              Text(
                solicitud.numeroExpediente!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Row('Monto aprobado', ClienteRepository.formatBalance(monto)),
            if (solicitud.plazoMeses != null)
              _Row('Plazo', '${solicitud.plazoMeses} meses'),
            if (solicitud.teaReferencial != null)
              _Row('TEA', '${solicitud.teaReferencial}%'),
            if (solicitud.cuotaMensualMostrada != null)
              _Row(
                'Cuota mensual',
                ClienteRepository.formatBalance(solicitud.cuotaMensualMostrada),
              ),
            if (solicitud.nombreNegocio != null && solicitud.nombreNegocio!.isNotEmpty)
              _Row('Negocio', solicitud.nombreNegocio!),
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String? estado;

  @override
  Widget build(BuildContext context) {
    final label = SolicitudModel.labelForEstado(estado);
    final color = estado == 'desembolsada'
        ? AppColors.primary
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
