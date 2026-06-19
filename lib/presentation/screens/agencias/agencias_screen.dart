import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/agencia_model.dart';
import '../../viewmodels/agencias_view_model.dart';

class AgenciasScreen extends StatefulWidget {
  const AgenciasScreen({super.key, this.viewModel});

  final AgenciasViewModel? viewModel;

  @override
  State<AgenciasScreen> createState() => _AgenciasScreenState();
}

class _AgenciasScreenState extends State<AgenciasScreen> {
  late final AgenciasViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? AgenciasViewModel();
    _viewModel.load();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openMaps(AgenciaModel agencia) async {
    final lat = agencia.lat;
    final lng = agencia.lng;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agencias y sucursales'),
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_viewModel.error!),
              ),
            );
          }

          if (_viewModel.agencias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay agencias disponibles en este momento.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _viewModel.agencias.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agencia = _viewModel.agencias[index];
                final hasCoords = agencia.lat != null && agencia.lng != null;

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    border: Border.all(color: AppColors.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(Icons.store, color: AppColors.primary),
                    ),
                    title: Text(
                      agencia.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: agencia.region != null
                        ? Text(agencia.region!)
                        : null,
                    trailing: hasCoords
                        ? IconButton(
                            tooltip: 'Ver en mapa',
                            onPressed: () => _openMaps(agencia),
                            icon: const Icon(Icons.map_outlined),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
