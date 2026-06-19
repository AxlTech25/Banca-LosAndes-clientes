import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/solicitudes/solicitud_repository.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../widgets/primary_action_button.dart';

class SolicitudDocumentosScreen extends StatefulWidget {
  const SolicitudDocumentosScreen({
    super.key,
    required this.solicitudId,
    this.numeroExpediente,
    this.canUpload = true,
  });

  final String solicitudId;
  final String? numeroExpediente;
  final bool canUpload;

  @override
  State<SolicitudDocumentosScreen> createState() =>
      _SolicitudDocumentosScreenState();
}

class _SolicitudDocumentosScreenState extends State<SolicitudDocumentosScreen> {
  final _repository = SolicitudRepository();

  List<SolicitudDocumentoModel> _documentos = [];
  bool _isLoading = true;
  String? _uploadingTipo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final docs = await _repository.fetchDocumentos(widget.solicitudId);
    if (!mounted) return;
    setState(() {
      _documentos = docs;
      _isLoading = false;
    });
  }

  SolicitudDocumentoModel? _docForTipo(String tipo) {
    for (final doc in _documentos) {
      if (doc.tipoDocumento == tipo) return doc;
    }
    return null;
  }

  Future<void> _pickAndUpload(String tipo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo.')),
      );
      return;
    }

    setState(() => _uploadingTipo = tipo);

    try {
      await _repository.subirDocumento(
        solicitudId: widget.solicitudId,
        tipoDocumento: tipo,
        bytes: Uint8List.fromList(bytes),
        extension: _extension(file.name),
        mimeType: _mimeType(file.name),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DocumentoTipos.label(tipo)} subido.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploadingTipo = null);
    }
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return 'jpg';
    return name.substring(dot + 1).toLowerCase();
  }

  String _mimeType(String name) {
    final ext = _extension(name);
    return switch (ext) {
      'png' => 'image/png',
      'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }

  bool get _completo {
    for (final tipo in DocumentoTipos.requeridos) {
      if (_docForTipo(tipo) == null) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.numeroExpediente ?? 'Solicitud',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.canUpload
                      ? 'Sube fotos JPG o PNG (max. 1 MB) de los documentos requeridos.'
                      : 'Documentos adjuntos a tu solicitud.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ...DocumentoTipos.requeridos.map(
                  (tipo) => _DocumentoTile(
                    tipo: tipo,
                    documento: _docForTipo(tipo),
                    isUploading: _uploadingTipo == tipo,
                    canUpload: widget.canUpload,
                    onUpload: () => _pickAndUpload(tipo),
                    onPreview: () async {
                      final doc = _docForTipo(tipo);
                      if (doc?.storageUrl == null) return;
                      final url = await _repository.getDocumentoSignedUrl(
                        doc!.storageUrl!,
                      );
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.canUpload) ...[
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: _completo ? 'Listo' : 'Continuar sin completar',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  const _DocumentoTile({
    required this.tipo,
    required this.documento,
    required this.isUploading,
    required this.canUpload,
    required this.onUpload,
    required this.onPreview,
  });

  final String tipo;
  final SolicitudDocumentoModel? documento;
  final bool isUploading;
  final bool canUpload;
  final VoidCallback onUpload;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final subido = documento != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: subido
              ? AppColors.primaryContainer
              : AppColors.primaryFixed,
          child: Icon(
            subido ? Icons.check : Icons.upload_file,
            color: subido ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
        title: Text(DocumentoTipos.label(tipo)),
        subtitle: Text(
          subido
              ? '${documento!.tamanioKb ?? 0} KB · Subido'
              : 'Pendiente de subir',
        ),
        trailing: isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : subido
            ? IconButton(
                icon: const Icon(Icons.visibility_outlined),
                onPressed: onPreview,
              )
            : canUpload
            ? IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: onUpload,
              )
            : null,
        onTap: subido ? onPreview : (canUpload ? onUpload : null),
      ),
    );
  }
}
