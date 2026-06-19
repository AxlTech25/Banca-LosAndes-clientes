import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/realtime_helper.dart';
import '../../data/clientes/cliente_repository.dart';
import '../../data/cuentas/cuenta_repository.dart';
import '../../domain/models/movimiento_cuenta_model.dart';

class CuentaViewModel extends ChangeNotifier {
  CuentaViewModel({CuentaRepository? repository})
    : _repository = repository ?? CuentaRepository();

  final CuentaRepository _repository;

  Map<String, dynamic>? _cuenta;
  List<MovimientoCuentaModel> _movimientos = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  RealtimeChannel? _cuentasChannel;
  RealtimeChannel? _movimientosChannel;

  Map<String, dynamic>? get cuenta => _cuenta;
  List<MovimientoCuentaModel> get movimientos => _movimientos;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  String get numeroCuenta => _cuenta?['numero_cuenta']?.toString() ?? '-';
  String get saldo =>
      ClienteRepository.formatBalance(_parseNum(_cuenta?['saldo_disponible']));

  void startListening() {
    _cuentasChannel?.unsubscribe();
    _movimientosChannel?.unsubscribe();
    _cuentasChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-cuentas',
      table: 'cuentas',
      onChange: load,
    );
    _movimientosChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-movimientos',
      table: 'movimientos_cuenta',
      onChange: load,
    );
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchCuentaAhorros(),
        _repository.fetchMovimientos(),
      ]);
      _cuenta = results[0] as Map<String, dynamic>?;
      _movimientos = results[1] as List<MovimientoCuentaModel>;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> depositar({required double monto, String? concepto}) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.registrarDepositoSimulado(
        monto: monto,
        concepto: concepto,
      );
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> transferir({
    required String cuentaDestino,
    required double monto,
    String? concepto,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.registrarTransferenciaSimulada(
        numeroCuentaDestino: cuentaDestino,
        monto: monto,
        concepto: concepto,
      );
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  @override
  void dispose() {
    RealtimeHelper.unsubscribe(_cuentasChannel);
    RealtimeHelper.unsubscribe(_movimientosChannel);
    super.dispose();
  }
}
