import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/realtime_helper.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/solicitudes/solicitud_repository.dart';
import '../../domain/models/solicitud_model.dart';

class RequestCreditViewModel extends ChangeNotifier {
  RequestCreditViewModel({
    AuthRepository? authRepository,
    SolicitudRepository? solicitudRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _solicitudRepository = solicitudRepository ?? SolicitudRepository();

  final AuthRepository _authRepository;
  final SolicitudRepository _solicitudRepository;

  List<SolicitudModel> _solicitudes = [];
  List<PreaprobadoModel> _preaprobados = [];
  List<CampanaModel> _campanas = [];
  Map<String, dynamic>? _cliente;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  RealtimeChannel? _solicitudesChannel;

  List<SolicitudModel> get solicitudes => _solicitudes;
  List<PreaprobadoModel> get preaprobados => _preaprobados;
  List<CampanaModel> get campanas => _campanas;
  Map<String, dynamic>? get cliente => _cliente;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  String? get clienteTipoNegocio => _cliente?['tipo_negocio']?.toString();
  String? get clienteNombreNegocio => _cliente?['nombre_negocio']?.toString();
  int? get clienteAntiguedadMeses =>
      _parseInt(_cliente?['antiguedad_negocio_meses']);
  double? get clienteIngresos =>
      _parseDouble(_cliente?['ingresos_estimados']);

  void startListening() {
    _solicitudesChannel?.unsubscribe();
    _solicitudesChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-solicitudes',
      table: 'solicitudes_credito',
      onChange: load,
    );
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _cliente = await _authRepository.fetchCurrentCliente();
      final results = await Future.wait([
        _solicitudRepository.fetchSolicitudes(),
        _solicitudRepository.fetchPreaprobados(),
        _solicitudRepository.fetchCampanas(),
      ]);
      _solicitudes = results[0] as List<SolicitudModel>;
      _preaprobados = results[1] as List<PreaprobadoModel>;
      _campanas = results[2] as List<CampanaModel>;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SolicitudModel?> enviarSolicitud(
    NuevaSolicitudInput input, {
    String? firmaBase64,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final solicitud = await _solicitudRepository.crearSolicitud(
        input,
        firmaBase64: firmaBase64,
      );
      await load();
      return solicitud;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    RealtimeHelper.unsubscribe(_solicitudesChannel);
    super.dispose();
  }
}
