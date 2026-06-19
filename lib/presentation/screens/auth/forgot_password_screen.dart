import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/auth/auth_repository.dart';
import '../../viewmodels/forgot_password_view_model.dart';
import '../../widgets/banco_los_andes_logo.dart';
import '../../widgets/los_andes_text_field.dart';
import '../../widgets/primary_action_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _viewModel = ForgotPasswordViewModel();

  @override
  void dispose() {
    _dniController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _viewModel.lookupDni(_dniController.text.trim());
  }

  Future<void> _sendReset() async {
    final dni = _dniController.text.trim();
    final ok = await _viewModel.sendReset(dni);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si tu cuenta existe, recibiras un enlace para restablecer tu contrasena.',
          ),
        ),
      );
    } else if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contrasena')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: BancoLosAndesLogo(
                            width: 140,
                            height: 140,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ingresa tu DNI para recuperar el acceso a tu cuenta.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        LosAndesTextField(
                          controller: _dniController,
                          label: 'DNI',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final dni = value?.trim() ?? '';
                            if (dni.length < 8) {
                              return 'Ingresa un DNI valido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _viewModel.isLoading ? null : _lookup,
                          child: _viewModel.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Verificar cuenta'),
                        ),
                        if (_viewModel.hint != null) ...[
                          const SizedBox(height: 16),
                          _HintCard(hint: _viewModel.hint!),
                        ],
                        const SizedBox(height: 24),
                        PrimaryActionButton(
                          label: 'Enviar enlace de recuperacion',
                          isLoading: _viewModel.isSubmitting,
                          onPressed: _viewModel.sent ? null : _sendReset,
                        ),
                        if (_viewModel.sent) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Revisa tu correo o la bandeja de Supabase Auth '
                            '(en desarrollo). El enlace usa el email de autenticacion '
                            'vinculado a tu DNI.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.hint});

  final PasswordRecoveryHint hint;

  @override
  Widget build(BuildContext context) {
    if (!hint.found) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No encontramos una cuenta registrada con ese DNI.',
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuenta encontrada',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint.emailMasked != null) ...[
              const SizedBox(height: 8),
              Text('Email: ${hint.emailMasked}'),
            ],
            if (hint.telefonoMasked != null) ...[
              const SizedBox(height: 4),
              Text('Telefono: ${hint.telefonoMasked}'),
            ],
          ],
        ),
      ),
    );
  }
}
