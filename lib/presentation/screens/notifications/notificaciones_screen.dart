import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/notificaciones/notificacion_repository.dart';
import '../../viewmodels/notificaciones_view_model.dart';
import '../request/solicitud_detail_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, required this.viewModel});

  final NotificacionesViewModel viewModel;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  Future<void> _openNotificacion(NotificacionModel n) async {
    await widget.viewModel.marcarLeida(n);

    if (!mounted) return;

    if (n.referenciaTipo == 'solicitud' && n.referenciaId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SolicitudDetailScreen(solicitudId: n.referenciaId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: widget.viewModel.marcarTodasLeidas,
            child: const Text('Marcar leidas'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, _) {
          if (widget.viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.viewModel.notificaciones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tienes notificaciones.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: widget.viewModel.load,
            child: ListView.separated(
              itemCount: widget.viewModel.notificaciones.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = widget.viewModel.notificaciones[index];
                return ListTile(
                  tileColor: n.leida
                      ? null
                      : AppColors.primaryContainer.withValues(alpha: 0.15),
                  leading: Icon(
                    _iconForTipo(n.tipo),
                    color: n.leida ? AppColors.outline : AppColors.primary,
                  ),
                  title: Text(
                    n.titulo,
                    style: TextStyle(
                      fontWeight: n.leida ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(n.mensaje, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: n.leida
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () => _openNotificacion(n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconForTipo(String tipo) {
    return switch (tipo) {
      'solicitud_estado' => Icons.description_outlined,
      'credito' => Icons.payments_outlined,
      'pago' => Icons.receipt_long_outlined,
      _ => Icons.notifications_outlined,
    };
  }
}
