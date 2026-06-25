import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/credit_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/credit_product_models.dart';
import '../../../domain/models/solicitud_model.dart';
import '../../viewmodels/request_credit_view_model.dart';
import '../../widgets/los_andes_text_field.dart';
import '../../widgets/primary_action_button.dart';
import 'firma_solicitud_sheet.dart';
import 'solicitud_documentos_screen.dart';

class NewSolicitudScreen extends StatefulWidget {
  const NewSolicitudScreen({
    super.key,
    required this.viewModel,
    this.prefilled,
  });

  final RequestCreditViewModel viewModel;
  final SolicitudCreditoPrefill? prefilled;

  @override
  State<NewSolicitudScreen> createState() => _NewSolicitudScreenState();
}

class _NewSolicitudScreenState extends State<NewSolicitudScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _montoController = TextEditingController(
    text: widget.prefilled != null
        ? '${widget.prefilled!.montoSolicitado}'
        : '',
  );
  late final _plazoController = TextEditingController(
    text: widget.prefilled != null ? '${widget.prefilled!.plazoMeses}' : '12',
  );
  late final _destinoController = TextEditingController(
    text: widget.prefilled?.destinoCredito ?? '',
  );

  late bool _conSeguroDesgravamen =
      widget.prefilled?.conSeguroDesgravamen ?? false;
  late String _garantia =
      widget.prefilled?.garantia ?? GarantiaTipos.sinGarantia;

  @override
  void initState() {
    super.initState();
    for (final controller in [_montoController, _plazoController]) {
      controller.addListener(_onFormChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _montoController,
      _plazoController,
      _destinoController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  double? get _monto => double.tryParse(_montoController.text.trim());
  int? get _plazo => int.tryParse(_plazoController.text.trim());

  double get _teaAplicada => _conSeguroDesgravamen
      ? CreditoProducto.teaConDesgravamen
      : CreditoProducto.teaSinDesgravamen;

  double? get _cuotaReferencia {
    final monto = _monto;
    final plazo = _plazo;
    if (monto == null || plazo == null || monto <= 0 || plazo <= 0) {
      return null;
    }
    return CreditCalculator.cuotaFrancesa(
      monto: monto,
      plazoMeses: plazo,
      teaPercent: _teaAplicada,
    );
  }

  Future<void> _submit() async {
    if (!widget.viewModel.perfilNegocioCompleto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu perfil de negocio no esta completo. Contacta soporte o vuelve a registrarte.',
          ),
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final monto = _monto!;
    final plazo = _plazo!;
    final tea = widget.prefilled?.teaReferencial ?? _teaAplicada;
    final cuota = _cuotaReferencia!;

    final input = widget.viewModel.buildSolicitudInput(
      montoSolicitado: monto,
      plazoMeses: plazo,
      destinoCredito: _destinoController.text.trim(),
      garantia: _garantia,
      conSeguroDesgravamen: _conSeguroDesgravamen,
      teaReferencial: tea,
      cuotaEstimada: double.parse(cuota.toStringAsFixed(2)),
    );

    if (input == null) return;

    SolicitudModel? created;

    final firmado = await showFirmaSolicitudSheet(
      context,
      onConfirm: (firma) async {
        created = await widget.viewModel.enviarSolicitud(
          input,
          firmaBase64: firma,
        );
        if (created == null) {
          throw Exception(
            widget.viewModel.error ?? 'No se pudo enviar la solicitud.',
          );
        }
      },
    );

    if (!mounted) return;

    if (firmado == true && created != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SolicitudDocumentosScreen(
            solicitudId: created!.id,
            numeroExpediente: created!.numeroExpediente,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } else if (firmado != true && widget.viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuota = _cuotaReferencia;
    final vm = widget.viewModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar credito')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Indica el credito que necesitas. Usaremos los datos de tu perfil.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (!vm.perfilNegocioCompleto)
                const _PerfilIncompletoCard()
              else
                _PerfilNegocioCard(viewModel: vm),
              const SizedBox(height: 20),
              _ProductoCard(
                tea: _teaAplicada,
                cuotaReferencia: cuota,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir seguro de desgravamen'),
                subtitle: Text(
                  _conSeguroDesgravamen
                      ? 'TEA ${CreditoProducto.teaConDesgravamen}%'
                      : 'TEA ${CreditoProducto.teaSinDesgravamen}% (sin seguro)',
                ),
                value: _conSeguroDesgravamen,
                activeThumbColor: AppColors.primary,
                onChanged: (value) => setState(() => _conSeguroDesgravamen = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _garantia,
                decoration: const InputDecoration(
                  labelText: 'Garantia',
                  border: OutlineInputBorder(),
                ),
                items: GarantiaTipos.opciones.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _garantia = value);
                },
              ),
              const SizedBox(height: 16),
              LosAndesTextField(
                controller: _montoController,
                label: 'Monto solicitado (S/)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumber,
              ),
              LosAndesTextField(
                controller: _plazoController,
                label: 'Plazo (meses)',
                keyboardType: TextInputType.number,
                validator: _positiveInt,
              ),
              LosAndesTextField(
                controller: _destinoController,
                label: 'Destino del credito',
                validator: _required,
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: widget.viewModel,
                builder: (context, _) {
                  return PrimaryActionButton(
                    label: 'Enviar solicitud',
                    isLoading: widget.viewModel.isSubmitting,
                    onPressed: vm.perfilNegocioCompleto ? _submit : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _PerfilIncompletoCard extends StatelessWidget {
  const _PerfilIncompletoCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No encontramos los datos de tu negocio en tu perfil. '
          'Debes completarlos al registrarte para poder solicitar credito.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _PerfilNegocioCard extends StatelessWidget {
  const _PerfilNegocioCard({required this.viewModel});

  final RequestCreditViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos del solicitante',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            _InfoLine(label: 'Solicitante', value: viewModel.clienteNombreCompleto),
            _InfoLine(label: 'Negocio', value: viewModel.clienteNombreNegocio ?? '-'),
            _InfoLine(label: 'Tipo', value: viewModel.clienteTipoNegocio ?? '-'),
            _InfoLine(label: 'Ubicacion', value: viewModel.clienteUbicacion ?? '-'),
            _InfoLine(
              label: 'Antiguedad',
              value: '${viewModel.clienteAntiguedadMeses ?? '-'} meses',
            ),
            _InfoLine(
              label: 'Ingresos mensuales',
              value: CurrencyFormatter.pen(viewModel.clienteIngresos),
            ),
            _InfoLine(
              label: 'Gastos mensuales',
              value: CurrencyFormatter.pen(viewModel.clienteGastosMensuales),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({
    required this.tea,
    required this.cuotaReferencia,
  });

  final double tea;
  final double? cuotaReferencia;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CreditoProducto.nombre,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InfoLine(label: 'TEA referencial', value: '${tea.toStringAsFixed(2)}%'),
            const SizedBox(height: 6),
            _InfoLine(
              label: 'Cuota referencia',
              value: cuotaReferencia != null
                  ? CurrencyFormatter.pen(cuotaReferencia)
                  : 'Completa monto y plazo',
              emphasized: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuota fija calculada con amortizacion francesa.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                color: emphasized ? AppColors.primary : AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
