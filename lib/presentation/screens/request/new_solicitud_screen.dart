import 'package:flutter/material.dart';

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
  final NuevaSolicitudInput? prefilled;

  @override
  State<NewSolicitudScreen> createState() => _NewSolicitudScreenState();
}

class _NewSolicitudScreenState extends State<NewSolicitudScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tipoNegocioController = TextEditingController(
    text: widget.prefilled?.tipoNegocio ?? widget.viewModel.clienteTipoNegocio ?? '',
  );
  late final _nombreNegocioController = TextEditingController(
    text: widget.prefilled?.nombreNegocio ?? widget.viewModel.clienteNombreNegocio ?? '',
  );
  late final _antiguedadController = TextEditingController(
    text: '${widget.prefilled?.antiguedadMeses ?? widget.viewModel.clienteAntiguedadMeses ?? ''}',
  );
  late final _ingresosController = TextEditingController(
    text: '${widget.prefilled?.ingresosEstimados ?? widget.viewModel.clienteIngresos ?? ''}',
  );
  late final _montoController = TextEditingController(
    text: widget.prefilled != null ? '${widget.prefilled!.montoSolicitado}' : '',
  );
  late final _plazoController = TextEditingController(
    text: widget.prefilled != null ? '${widget.prefilled!.plazoMeses}' : '12',
  );
  late final _destinoController = TextEditingController(
    text: widget.prefilled?.destinoCredito ?? '',
  );

  @override
  void dispose() {
    _tipoNegocioController.dispose();
    _nombreNegocioController.dispose();
    _antiguedadController.dispose();
    _ingresosController.dispose();
    _montoController.dispose();
    _plazoController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final input = NuevaSolicitudInput(
      tipoNegocio: _tipoNegocioController.text.trim(),
      nombreNegocio: _nombreNegocioController.text.trim(),
      antiguedadMeses: int.parse(_antiguedadController.text.trim()),
      ingresosEstimados: double.parse(_ingresosController.text.trim()),
      montoSolicitado: double.parse(_montoController.text.trim()),
      plazoMeses: int.parse(_plazoController.text.trim()),
      destinoCredito: _destinoController.text.trim(),
    );

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
                'Completa los datos de tu negocio y el credito que necesitas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              LosAndesTextField(
                controller: _tipoNegocioController,
                label: 'Tipo de negocio',
                validator: _required,
              ),
              LosAndesTextField(
                controller: _nombreNegocioController,
                label: 'Nombre del negocio',
                validator: _required,
              ),
              LosAndesTextField(
                controller: _antiguedadController,
                label: 'Antiguedad del negocio (meses)',
                keyboardType: TextInputType.number,
                validator: _positiveInt,
              ),
              LosAndesTextField(
                controller: _ingresosController,
                label: 'Ingresos estimados mensuales (S/)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumber,
              ),
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
                    onPressed: _submit,
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
