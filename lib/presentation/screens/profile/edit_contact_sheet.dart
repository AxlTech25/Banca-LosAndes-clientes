import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/profile_view_model.dart';

Future<void> showEditContactSheet(
  BuildContext context,
  ProfileViewModel viewModel,
) async {
  final emailController = TextEditingController(
    text: viewModel.email == 'No registrado' ? '' : viewModel.email,
  );
  final telefonoController = TextEditingController(
    text: viewModel.telefono == 'No registrado' ? '' : viewModel.telefono,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            return Column(
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
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (viewModel.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: viewModel.isSaving
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final telefono = telefonoController.text.trim();
                          if (email.isEmpty || telefono.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completa email y telefono.'),
                              ),
                            );
                            return;
                          }

                          final ok = await viewModel.updateContacto(
                            email: email,
                            telefono: telefono,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Datos actualizados.'),
                              ),
                            );
                          }
                        },
                  child: viewModel.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  emailController.dispose();
  telefonoController.dispose();
}
