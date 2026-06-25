import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/profile_view_model.dart';

Future<void> showEditNegocioSheet(
  BuildContext context,
  ProfileViewModel viewModel,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _EditNegocioSheet(
        viewModel: viewModel,
        onSaved: () => Navigator.of(sheetContext).pop(true),
      );
    },
  );

  if (saved == true) {
    await viewModel.refreshProfile();
    messenger.showSnackBar(
      const SnackBar(content: Text('Datos del negocio actualizados.')),
    );
  }
}

class _EditNegocioSheet extends StatefulWidget {
  const _EditNegocioSheet({
    required this.viewModel,
    required this.onSaved,
  });

  final ProfileViewModel viewModel;
  final VoidCallback onSaved;

  @override
  State<_EditNegocioSheet> createState() => _EditNegocioSheetState();
}

class _EditNegocioSheetState extends State<_EditNegocioSheet> {
  late final _tipoController = TextEditingController(
    text: widget.viewModel.tipoNegocio ?? '',
  );
  late final _nombreController = TextEditingController(
    text: widget.viewModel.nombreNegocio ?? '',
  );
  late final _ubicacionController = TextEditingController(
    text: widget.viewModel.ubicacionNegocio ?? '',
  );
  late final _antiguedadController = TextEditingController(
    text: widget.viewModel.antiguedadNegocioMeses?.toString() ?? '',
  );
  late final _ingresosController = TextEditingController(
    text: widget.viewModel.ingresosEstimadosValor?.toString() ?? '',
  );
  late final _gastosController = TextEditingController(
    text: widget.viewModel.gastosMensualesValor?.toString() ?? '',
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _tipoController.dispose();
    _nombreController.dispose();
    _ubicacionController.dispose();
    _antiguedadController.dispose();
    _ingresosController.dispose();
    _gastosController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tipo = _tipoController.text.trim();
    final nombre = _nombreController.text.trim();
    final ubicacion = _ubicacionController.text.trim();
    final antiguedad = int.tryParse(_antiguedadController.text.trim());
    final ingresos = double.tryParse(_ingresosController.text.trim());
    final gastos = double.tryParse(_gastosController.text.trim());

    if (tipo.isEmpty ||
        nombre.isEmpty ||
        ubicacion.isEmpty ||
        antiguedad == null ||
        antiguedad <= 0 ||
        ingresos == null ||
        ingresos <= 0 ||
        gastos == null ||
        gastos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos con valores validos.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final ok = await widget.viewModel.updatePerfilNegocio(
      tipoNegocio: tipo,
      nombreNegocio: nombre,
      ubicacionNegocio: ubicacion,
      antiguedadMeses: antiguedad,
      ingresosEstimados: ingresos,
      gastosMensuales: gastos,
    );

    if (!mounted) return;

    if (ok) {
      widget.onSaved();
      return;
    }

    setState(() {
      _isSaving = false;
      _error = widget.viewModel.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar datos del negocio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tipoController,
              decoration: const InputDecoration(
                labelText: 'Tipo de negocio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del negocio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ubicacionController,
              decoration: const InputDecoration(
                labelText: 'Ubicacion (distrito)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _antiguedadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Antiguedad del negocio (meses)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ingresosController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Ingresos mensuales estimados (S/)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gastosController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Gastos mensuales (S/)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
