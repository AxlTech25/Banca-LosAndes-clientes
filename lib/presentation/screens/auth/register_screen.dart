import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/register_view_model.dart';
import '../../widgets/primary_action_button.dart';
import '../../widgets/underlined_los_andes_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAs4iXmx_MXN7tswwjPTAGLHZ1bgb1HltEm63mGF_fkmS_QNfc37w1HWDkCPzUet7nG-L4o_AQCnorUmbI4YKGoMlgoYQWXALU8ON18KJz8F6g_2YP6oekD_FzyeS2QrLlUP9B5BYdXD--EUrcxHdlP7ge2omTLqqP6eBlwkeWrvLPxWS0nh7Dz83S-WpGdJz5N69AtqHGox5VLHbUJpBedU_YVTcbu6YXl74tZXYNHzWDRc1kmrtM7RULv-_42MJ9XPrL6oK72aQ';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _viewModel = RegisterViewModel();

  @override
  void dispose() {
    _nameController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _viewModel.createAccount(
      fullName: _nameController.text.trim(),
      dni: _dniController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registro listo para conectar con Supabase.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: const _RegisterAppBar(logoUrl: _logoUrl),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: _RegisterCard(
                    formKey: _formKey,
                    nameController: _nameController,
                    dniController: _dniController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    viewModel: _viewModel,
                    onSubmit: _submit,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RegisterAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _RegisterAppBar({required this.logoUrl});

  final String logoUrl;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      toolbarHeight: 48,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      titleSpacing: 0,
      title: SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              ),
            ),
            Expanded(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.network(
                      logoUrl,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.account_balance,
                          color: AppColors.onPrimary,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48, height: 48),
          ],
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.formKey,
    required this.nameController,
    required this.dniController,
    required this.emailController,
    required this.passwordController,
    required this.viewModel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController dniController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final RegisterViewModel viewModel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              const _RegisterHeader(),
              const SizedBox(height: 32),
              UnderlinedLosAndesTextField(
                controller: nameController,
                label: 'Nombre completo',
                keyboardType: TextInputType.name,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu nombre completo';
                  }
                  if (value.trim().split(RegExp(r'\s+')).length < 2) {
                    return 'Ingresa nombre y apellido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: dniController,
                label: 'DNI',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final dni = value?.trim() ?? '';
                  if (dni.isEmpty) {
                    return 'Ingresa tu DNI';
                  }
                  if (dni.length < 8) {
                    return 'El DNI debe tener al menos 8 digitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: emailController,
                label: 'Correo electr\u00f3nico',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Ingresa tu correo electr\u00f3nico';
                  }
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Ingresa un correo v\u00e1lido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: passwordController,
                label: 'Contrase\u00f1a',
                obscureText: !viewModel.passwordVisible,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  tooltip: viewModel.passwordVisible
                      ? 'Ocultar contrase\u00f1a'
                      : 'Mostrar contrase\u00f1a',
                  onPressed: viewModel.togglePasswordVisibility,
                  icon: Icon(
                    viewModel.passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.outline,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa una contrase\u00f1a';
                  }
                  if (value.length < 6) {
                    return 'Usa al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 34),
              PrimaryActionButton(
                label: 'Crear Cuenta',
                isLoading: viewModel.isSubmitting,
                onPressed: onSubmit,
              ),
              const SizedBox(height: 24),
              const _LoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Crear Cuenta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete sus datos para registrarse',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '\u00bfYa tienes cuenta? ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Iniciar sesi\u00f3n',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
