import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/buro/buro_repository.dart';
import '../../../domain/models/fase4_models.dart';

class BuroResumidoScreen extends StatefulWidget {
  const BuroResumidoScreen({super.key});

  @override
  State<BuroResumidoScreen> createState() => _BuroResumidoScreenState();
}

class _BuroResumidoScreenState extends State<BuroResumidoScreen> {
  final _repository = BuroRepository();
  BuroResumidoModel? _buro;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final buro = await _repository.fetchResumen();
    if (!mounted) return;
    setState(() {
      _buro = buro;
      _isLoading = false;
    });
  }

  Color _colorForCalificacion(String? cal) {
    return switch (cal) {
      'Normal' => AppColors.primary,
      'CPP' => Colors.orange,
      'Deficiente' => AppColors.error,
      'Dudoso' => Colors.deepOrange,
      'Pérdida' => Colors.red.shade900,
      _ => AppColors.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi calificacion crediticia')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_buro == null)
                    const Center(child: Text('Informacion no disponible'))
                  else ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _colorForCalificacion(_buro!.calificacionSbs)
                            .withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              'Calificacion SBS',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _buro!.calificacionLabel,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: _colorForCalificacion(
                                      _buro!.calificacionSbs,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (_buro!.descripcion != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _buro!.descripcion!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_buro!.entidadesConDeuda != null)
                      _InfoTile(
                        'Entidades con deuda',
                        '${_buro!.entidadesConDeuda}',
                      ),
                    if (_buro!.fechaUltimaConsulta != null)
                      _InfoTile(
                        'Ultima consulta',
                        _buro!.fechaUltimaConsulta!.substring(0, 10),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Esta es una vista resumida. El detalle completo del buró '
                      'solo lo gestiona tu asesor en el proceso de evaluacion.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
