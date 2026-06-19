import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_colors.dart';

/// Muestra la firma en un recuadro dentro de un bottom sheet (no pantalla completa).
Future<bool?> showFirmaSolicitudSheet(
  BuildContext context, {
  required Future<void> Function(String firmaBase64) onConfirm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _FirmaSheetBody(onConfirm: onConfirm);
    },
  );
}

class _FirmaSheetBody extends StatefulWidget {
  const _FirmaSheetBody({required this.onConfirm});

  final Future<void> Function(String firmaBase64) onConfirm;

  @override
  State<_FirmaSheetBody> createState() => _FirmaSheetBodyState();
}

class _FirmaSheetBodyState extends State<_FirmaSheetBody> {
  late final SignatureController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _hecho() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dibuja tu firma en el recuadro.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No se pudo capturar la firma.');
      }
      await widget.onConfirm(base64Encode(bytes));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Firma digital',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Firma dentro del recuadro para autorizar tu solicitud.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.outline, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _controller.clear,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Borrar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _hecho,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: const Text('Hecho'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
