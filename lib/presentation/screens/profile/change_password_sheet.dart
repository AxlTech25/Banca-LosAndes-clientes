import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/change_password_view_model.dart';
import '../../widgets/primary_action_button.dart';

Future<void> showChangePasswordSheet(BuildContext context) async {
  final viewModel = ChangePasswordViewModel();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  var obscure = true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
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
                      'Cambiar contrasena',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Nueva contrasena',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contrasena',
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
                    PrimaryActionButton(
                      label: 'Actualizar contrasena',
                      isLoading: viewModel.isSubmitting,
                      onPressed: viewModel.isSubmitting
                          ? null
                          : () async {
                              final password = passwordController.text;
                              final confirm = confirmController.text;
                              if (password.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'La contrasena debe tener al menos 6 caracteres.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (password != confirm) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Las contrasenas no coinciden.'),
                                  ),
                                );
                                return;
                              }

                              final ok = await viewModel.changePassword(password);
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contrasena actualizada.'),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    },
  );

  passwordController.dispose();
  confirmController.dispose();
  viewModel.dispose();
}
