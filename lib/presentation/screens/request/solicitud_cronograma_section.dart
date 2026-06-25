import 'package:flutter/material.dart';

import '../../../domain/models/solicitud_model.dart';
import 'cronograma_pagos_section.dart';

class SolicitudCronogramaSection extends StatelessWidget {
  const SolicitudCronogramaSection({
    super.key,
    required this.solicitud,
    required this.cuotas,
  });

  final SolicitudModel solicitud;
  final List<CronogramaCuotaModel> cuotas;

  @override
  Widget build(BuildContext context) {
    if (!solicitud.muestraCronograma) return const SizedBox.shrink();

    return CronogramaPagosSection(
      cuotas: cuotas,
      cuotaMensual: solicitud.cuotaMensualMostrada,
      fechaDesembolsoProgramada: solicitud.fechaDesembolsoProgramada,
    );
  }
}
