import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/login_view_model.dart';
import '../../widgets/los_andes_text_field.dart';
import '../../widgets/primary_action_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAs4iXmx_MXN7tswwjPTAGLHZ1bgb1HltEm63mGF_fkmS_QNfc37w1HWDkCPzUet7nG-L4o_AQCnorUmbI4YKGoMlgoYQWXALU8ON18KJz8F6g_2YP6oekD_FzyeS2QrLlUP9B5BYdXD--EUrcxHdlP7ge2omTLqqP6eBlwkeWrvLPxWS0nh7Dz83S-WpGdJz5N69AtqHGox5VLHbUJpBedU_YVTcbu6YXl74tZXYNHzWDRc1kmrtM7RULv-_42MJ9XPrL6oK72aQ';

  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _viewModel = LoginViewModel();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _viewModel.signIn(
      user: _userController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LoginHeader(logoUrl: _logoUrl),
                      const SizedBox(height: 32),
                      _LoginCard(
                        formKey: _formKey,
                        userController: _userController,
                        passwordController: _passwordController,
                        viewModel: _viewModel,
                        onSubmit: _submit,
                      ),
                      const SizedBox(height: 32),
                      const _RegistrationPrompt(),
                    ],
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

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.network(
          logoUrl,
          width: 158,
          height: 68,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 158,
              height: 68,
              child: Icon(
                Icons.account_balance,
                color: AppColors.primary,
                size: 48,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Banco Los Andes',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.viewModel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final LoginViewModel viewModel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14006686),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              LosAndesTextField(
                controller: userController,
                label: 'Usuario / DNI',
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu usuario o DNI';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              LosAndesTextField(
                controller: passwordController,
                label: 'Contrase\u00f1a',
                obscureText: !viewModel.passwordVisible,
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
                    return 'Ingresa tu contrase\u00f1a';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _LoginOptions(viewModel: viewModel),
              const SizedBox(height: 26),
              PrimaryActionButton(
                label: 'Ingresar',
                isLoading: viewModel.isSubmitting,
                onPressed: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginOptions extends StatelessWidget {
  const _LoginOptions({required this.viewModel});

  final LoginViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: viewModel.rememberUser,
            onChanged: (value) => viewModel.setRememberUser(value ?? false),
            activeColor: AppColors.primary,
            side: const BorderSide(color: AppColors.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Recordar',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '\u00bfOlvidaste tu contrase\u00f1a?',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationPrompt extends StatelessWidget {
  const _RegistrationPrompt();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '\u00bfNo tienes cuenta? ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.register);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Reg\u00edstrate',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
