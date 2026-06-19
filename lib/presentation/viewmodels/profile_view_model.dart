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
  bool _isSaving = false;
  String? _error;

  Map<String, dynamic>? get cliente => _cliente;
  Map<String, dynamic>? get cuenta => _cuenta;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
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

  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _cliente = await _authRepository.fetchCurrentCliente();
      _cuenta = await _clienteRepository.fetchCuentaAhorros();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateContacto({
    required String email,
    required String telefono,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _clienteRepository.updateContacto(
        email: email,
        telefono: telefono,
      );
      await loadProfile();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _authRepository.signOut();

  num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
