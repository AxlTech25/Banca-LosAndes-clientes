import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/auth/auth_repository.dart';
import '../../viewmodels/register_view_model.dart';
import '../../widgets/banco_los_andes_logo.dart';
import '../../widgets/primary_action_button.dart';
import '../../widgets/underlined_los_andes_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dniController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tipoNegocioController = TextEditingController();
  final _nombreNegocioController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _antiguedadController = TextEditingController();
  final _ingresosController = TextEditingController();
  final _gastosController = TextEditingController();
  final _viewModel = RegisterViewModel();

  @override
  void dispose() {
    _nameController.dispose();
    _dniController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _tipoNegocioController.dispose();
    _nombreNegocioController.dispose();
    _ubicacionController.dispose();
    _antiguedadController.dispose();
    _ingresosController.dispose();
    _gastosController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await _viewModel.createAccount(
        fullName: _nameController.text.trim(),
        dni: _dniController.text.trim(),
        password: _passwordController.text,
        telefono: _telefonoController.text.trim(),
        tipoNegocio: _tipoNegocioController.text.trim(),
        nombreNegocio: _nombreNegocioController.text.trim(),
        ubicacionNegocio: _ubicacionController.text.trim(),
        antiguedadMeses: int.parse(_antiguedadController.text.trim()),
        ingresosEstimados: double.parse(_ingresosController.text.trim()),
        gastosMensuales: double.parse(_gastosController.text.trim()),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta creada correctamente.')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: const _RegisterAppBar(),
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
                    telefonoController: _telefonoController,
                    passwordController: _passwordController,
                    tipoNegocioController: _tipoNegocioController,
                    nombreNegocioController: _nombreNegocioController,
                    ubicacionController: _ubicacionController,
                    antiguedadController: _antiguedadController,
                    ingresosController: _ingresosController,
                    gastosController: _gastosController,
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
  const _RegisterAppBar();

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
                child: BancoLosAndesLogo(
                  height: 36,
                  borderRadius: BorderRadius.circular(6),
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
    required this.telefonoController,
    required this.passwordController,
    required this.tipoNegocioController,
    required this.nombreNegocioController,
    required this.ubicacionController,
    required this.antiguedadController,
    required this.ingresosController,
    required this.gastosController,
    required this.viewModel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController dniController;
  final TextEditingController telefonoController;
  final TextEditingController passwordController;
  final TextEditingController tipoNegocioController;
  final TextEditingController nombreNegocioController;
  final TextEditingController ubicacionController;
  final TextEditingController antiguedadController;
  final TextEditingController ingresosController;
  final TextEditingController gastosController;
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
                controller: telefonoController,
                label: 'Telefono',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final telefono = value?.trim() ?? '';
                  if (telefono.isEmpty) {
                    return 'Ingresa tu telefono';
                  }
                  if (telefono.length < 9) {
                    return 'El telefono debe tener al menos 9 digitos';
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
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Datos de tu negocio',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              UnderlinedLosAndesTextField(
                controller: tipoNegocioController,
                label: 'Tipo de negocio',
                validator: _required,
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: nombreNegocioController,
                label: 'Nombre del negocio',
                validator: _required,
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: ubicacionController,
                label: 'Ubicacion (distrito)',
                validator: _required,
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: antiguedadController,
                label: 'Antiguedad del negocio (meses)',
                keyboardType: TextInputType.number,
                validator: _positiveInt,
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: ingresosController,
                label: 'Ingresos mensuales estimados (S/)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumber,
              ),
              const SizedBox(height: 18),
              UnderlinedLosAndesTextField(
                controller: gastosController,
                label: 'Gastos mensuales (S/)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumber,
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
          'Complete sus datos personales y de su negocio',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo requerido';
  return null;
}

String? _positiveInt(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0) return 'Ingresa un numero valido';
  return null;
}

String? _positiveNumber(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0) return 'Ingresa un monto valido';
  return null;
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
