import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/clientes/cliente_repository.dart';
import '../../domain/models/solicitud_model.dart';

class CronogramaPagosSection extends StatelessWidget {
  const CronogramaPagosSection({
    super.key,
    required this.cuotas,
    this.cuotaMensual,
    this.fechaDesembolsoProgramada,
    this.descripcion =
        'Estas son las cuotas mensuales (amortizacion francesa, pagos el dia 15 de cada mes).',
  });

  final List<CronogramaCuotaModel> cuotas;
  final num? cuotaMensual;
  final String? fechaDesembolsoProgramada;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    if (cuotas.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cronograma final de pagos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (cuotaMensual != null) ...[
              const SizedBox(height: 12),
              Text(
                'Cuota mensual: ${ClienteRepository.formatBalance(cuotaMensual)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (fechaDesembolsoProgramada != null &&
                fechaDesembolsoProgramada!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Desembolso programado: ${_formatFecha(fechaDesembolsoProgramada!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('Fecha pago')),
                  DataColumn(label: Text('Cuota')),
                  DataColumn(label: Text('Capital')),
                  DataColumn(label: Text('Interés')),
                  DataColumn(label: Text('Saldo')),
                ],
                rows: [
                  for (final c in cuotas)
                    DataRow(
                      cells: [
                        DataCell(Text('${c.numeroCuota}')),
                        DataCell(Text(_formatFechaCuota(c.fechaPago))),
                        DataCell(Text(_pen(c.montoCuota))),
                        DataCell(Text(_pen(c.capital))),
                        DataCell(Text(_pen(c.interes))),
                        DataCell(Text(_pen(c.saldo))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _pen(double value) => ClienteRepository.formatBalance(value);

  static String _formatFechaCuota(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String _formatFecha(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return _formatFechaCuota(date);
  }
}
