import 'package:flutter/foundation.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/clientes/cliente_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    AuthRepository? authRepository,
    ClienteRepository? clienteRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _clienteRepository = clienteRepository ?? ClienteRepository();

  final AuthRepository _authRepository;
  final ClienteRepository _clienteRepository;

  Map<String, dynamic>? _cliente;
  Map<String, dynamic>? _cuenta;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? get cliente => _cliente;
  Map<String, dynamic>? get cuenta => _cuenta;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get fullName {
    final n = _cliente?['nombres']?.toString().trim() ?? '';
    final a = _cliente?['apellidos']?.toString().trim() ?? '';
    return [n, a].where((p) => p.isNotEmpty).join(' ');
  }

  String get dni => _cliente?['numero_documento']?.toString() ?? '-';
  String get email => _cliente?['email']?.toString() ?? 'No registrado';
  String get telefono => _cliente?['telefono']?.toString() ?? 'No registrado';
  String? get calificacionSbs => _cliente?['calificacion_sbs']?.toString();
  String get numeroCuenta => _cuenta?['numero_cuenta']?.toString() ?? '-';
  String get saldoCuenta => ClienteRepository.formatBalance(
    _parseNum(_cuenta?['saldo_disponible']),
  );
  String? get tipoNegocio => _cliente?['tipo_negocio']?.toString();
  String? get nombreNegocio => _cliente?['nombre_negocio']?.toString();
  String? get ubicacionNegocio => _cliente?['direccion']?.toString();
  int? get antiguedadNegocioMeses => _parseInt(_cliente?['antiguedad_negocio_meses']);
  String get ingresosEstimados => ClienteRepository.formatBalance(
    _parseNum(_cliente?['ingresos_estimados']),
  );
  String get gastosMensuales => ClienteRepository.formatBalance(
    _parseNum(_cliente?['gastos_mensuales']),
  );
  double? get ingresosEstimadosValor =>
      _parseNum(_cliente?['ingresos_estimados'])?.toDouble();
  double? get gastosMensualesValor =>
      _parseNum(_cliente?['gastos_mensuales'])?.toDouble();
  bool get tienePerfilNegocio {
    final tipo = tipoNegocio?.trim() ?? '';
    final nombre = nombreNegocio?.trim() ?? '';
    final ubicacion = ubicacionNegocio?.trim() ?? '';
    return tipo.isNotEmpty &&
        nombre.isNotEmpty &&
        ubicacion.isNotEmpty &&
        antiguedadNegocioMeses != null &&
        antiguedadNegocioMeses! > 0;
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _reloadClienteData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadClienteData() async {
    _cliente = await _authRepository.fetchCurrentCliente();
    _cuenta = await _clienteRepository.fetchCuentaAhorros();
  }

  Future<void> _refreshAfterSave() async {
    await _reloadClienteData();
    notifyListeners();
  }

  Future<void> refreshProfile() => _refreshAfterSave();

  Future<bool> updateContacto({
    required String email,
    required String telefono,
  }) async {
    _error = null;

    try {
      await _clienteRepository.updateContacto(
        email: email,
        telefono: telefono,
      );
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    }
  }

  Future<bool> updatePerfilNegocio({
    required String tipoNegocio,
    required String nombreNegocio,
    required String ubicacionNegocio,
    required int antiguedadMeses,
    required double ingresosEstimados,
    required double gastosMensuales,
  }) async {
    _error = null;

    try {
      await _authRepository.savePerfilNegocio(
        tipoNegocio: tipoNegocio,
        nombreNegocio: nombreNegocio,
        ubicacionNegocio: ubicacionNegocio,
        antiguedadMeses: antiguedadMeses,
        ingresosEstimados: ingresosEstimados,
        gastosMensuales: gastosMensuales,
      );
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    }
  }

  Future<void> signOut() => _authRepository.signOut();

  num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
