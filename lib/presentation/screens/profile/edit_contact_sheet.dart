import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/profile_view_model.dart';

Future<void> showEditContactSheet(
  BuildContext context,
  ProfileViewModel viewModel,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _EditContactSheet(
        viewModel: viewModel,
        onSaved: () => Navigator.of(sheetContext).pop(true),
      );
    },
  );

  if (saved == true) {
    await viewModel.refreshProfile();
    messenger.showSnackBar(
      const SnackBar(content: Text('Datos actualizados.')),
    );
  }
}

class _EditContactSheet extends StatefulWidget {
  const _EditContactSheet({
    required this.viewModel,
    required this.onSaved,
  });

  final ProfileViewModel viewModel;
  final VoidCallback onSaved;

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final _emailController = TextEditingController(
    text: widget.viewModel.email == 'No registrado' ? '' : widget.viewModel.email,
  );
  late final _telefonoController = TextEditingController(
    text: widget.viewModel.telefono == 'No registrado'
        ? ''
        : widget.viewModel.telefono,
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (email.isEmpty || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa email y telefono.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final ok = await widget.viewModel.updateContacto(
      email: email,
      telefono: telefono,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Editar contacto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefono',
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
    );
  }
}
