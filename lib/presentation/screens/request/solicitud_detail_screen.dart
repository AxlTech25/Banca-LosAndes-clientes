import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/clientes/cliente_repository.dart';
import '../../../data/solicitudes/solicitud_repository.dart';
import '../../../domain/models/solicitud_model.dart';
import '../credits/credito_cronograma_screen.dart';
import 'chat_solicitud_screen.dart';
import 'firma_solicitud_sheet.dart';
import 'solicitud_documentos_screen.dart';

class SolicitudDetailScreen extends StatefulWidget {
  const SolicitudDetailScreen({super.key, required this.solicitudId});

  final String solicitudId;

  @override
  State<SolicitudDetailScreen> createState() => _SolicitudDetailScreenState();
}

class _SolicitudDetailScreenState extends State<SolicitudDetailScreen> {
  final _repository = SolicitudRepository();

  SolicitudModel? _solicitud;
  List<HistorialEstadoModel> _historial = [];
  List<SolicitudDocumentoModel> _documentos = [];
  bool _isLoading = true;
  bool _isSavingFirma = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final solicitud = await _repository.fetchSolicitudById(widget.solicitudId);
    final historial = await _repository.fetchHistorial(widget.solicitudId);
    final documentos = await _repository.fetchDocumentos(widget.solicitudId);
    if (!mounted) return;
    setState(() {
      _solicitud = solicitud;
      _historial = historial;
      _documentos = documentos;
      _isLoading = false;
    });
  }

  Future<void> _openDocumentos() async {
    final solicitud = _solicitud;
    if (solicitud == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitudDocumentosScreen(
          solicitudId: solicitud.id,
          numeroExpediente: solicitud.numeroExpediente,
          canUpload: solicitud.puedeSubirDocumentos,
        ),
      ),
    );
    await _load();
  }

  void _openChat() {
    final solicitud = _solicitud;
    if (solicitud == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSolicitudScreen(
          solicitudId: solicitud.id,
          numeroExpediente: solicitud.numeroExpediente,
        ),
      ),
    );
  }

  Future<void> _firmarSolicitud() async {
    final solicitud = _solicitud;
    if (solicitud == null) return;

    await showFirmaSolicitudSheet(
      context,
      onConfirm: (firma) async {
        setState(() => _isSavingFirma = true);
        try {
          await _repository.guardarFirma(
            solicitudId: solicitud.id,
            firmaBase64: firma,
          );
        } finally {
          if (mounted) setState(() => _isSavingFirma = false);
        }
      },
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de solicitud')),
      floatingActionButton: _solicitud != null
          ? FloatingActionButton.extended(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Chat'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _solicitud == null
          ? const Center(child: Text('Solicitud no encontrada'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoCard(solicitud: _solicitud!),
                  if (_solicitud!.muestraCronograma) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Cronograma de pagos'),
                      subtitle: const Text(
                        'Tambien disponible en la pestaña Creditos.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreditoCronogramaScreen(
                              solicitudId: _solicitud!.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _solicitud!.tieneFirma
                          ? Icons.verified_outlined
                          : Icons.draw_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      _solicitud!.tieneFirma
                          ? 'Solicitud firmada'
                          : 'Firma pendiente',
                    ),
                    subtitle: Text(
                      _solicitud!.tieneFirma
                          ? 'Tu firma digital fue registrada.'
                          : 'Firma para autorizar tu solicitud.',
                    ),
                    trailing: _solicitud!.tieneFirma
                        ? null
                        : TextButton(
                            onPressed: _isSavingFirma ? null : _firmarSolicitud,
                            child: _isSavingFirma
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Firmar'),
                          ),
                  ),
                  if (_solicitud!.motivoRechazo != null) ...[
                    const SizedBox(height: 16),
                    _AlertBox(
                      title: 'Motivo',
                      message: _solicitud!.motivoRechazo!,
                      color: AppColors.errorContainer,
                    ),
                  ],
                  if (_solicitud!.condicionAdicional != null) ...[
                    const SizedBox(height: 16),
                    _AlertBox(
                      title: 'Condicion adicional',
                      message: _solicitud!.condicionAdicional!,
                      color: AppColors.primaryContainer,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DOCUMENTOS (${_documentos.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _openDocumentos,
                        child: Text(
                          _solicitud!.puedeSubirDocumentos
                              ? 'Gestionar'
                              : 'Ver',
                        ),
                      ),
                    ],
                  ),
                  if (_documentos.isEmpty)
                    Text(
                      'Aun no hay documentos adjuntos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._documentos.map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(d.tipoLabel),
                        subtitle: Text('${d.tamanioKb ?? 0} KB'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'SEGUIMIENTO',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_historial.isEmpty)
                    Text(
                      'Tu solicitud fue registrada y esta pendiente de revision.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._historial.map(
                      (h) => _TimelineTile(historial: h),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.solicitud});

  final SolicitudModel solicitud;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('Expediente', solicitud.numeroExpediente ?? '-'),
            _Row('Estado', solicitud.estadoLabel),
            _Row('Producto', solicitud.productoLabel),
            _Row(
              'Monto solicitado',
              ClienteRepository.formatBalance(solicitud.montoSolicitado),
            ),
            if (solicitud.montoAprobado != null)
              _Row(
                'Monto aprobado',
                ClienteRepository.formatBalance(solicitud.montoAprobado),
              ),
            _Row('Plazo', '${solicitud.plazoMeses ?? '-'} meses'),
            if (solicitud.teaReferencial != null)
              _Row('TEA referencial', '${solicitud.teaReferencial}%'),
            if (solicitud.cuotaMensualMostrada != null)
              _Row(
                solicitud.muestraCronograma ? 'Cuota mensual' : 'Cuota referencia',
                ClienteRepository.formatBalance(solicitud.cuotaMensualMostrada),
              ),
            if (solicitud.garantia != null)
              _Row('Garantia', solicitud.garantiaLabel),
            _Row('Negocio', solicitud.nombreNegocio ?? '-'),
            if (solicitud.ubicacionNegocio != null &&
                solicitud.ubicacionNegocio!.isNotEmpty)
              _Row('Ubicacion', solicitud.ubicacionNegocio!),
            if (solicitud.gastosMensuales != null)
              _Row(
                'Gastos mensuales',
                ClienteRepository.formatBalance(solicitud.gastosMensuales),
              ),
            _Row('Destino', solicitud.destinoCredito ?? '-'),
          ],
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
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

class _AlertBox extends StatelessWidget {
  const _AlertBox({
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.historial});

  final HistorialEstadoModel historial;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 16,
        child: Icon(Icons.circle, size: 10),
      ),
      title: Text(historial.estadoLabel),
      subtitle: Text(
        historial.createdAt?.substring(0, 16) ?? 'Actualizado',
      ),
    );
  }
}
