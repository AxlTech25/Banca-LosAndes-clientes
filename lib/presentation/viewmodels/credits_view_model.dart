import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/realtime_helper.dart';
import '../../data/clientes/cliente_repository.dart';

class CreditsViewModel extends ChangeNotifier {
  CreditsViewModel({ClienteRepository? clienteRepository})
    : _clienteRepository = clienteRepository ?? ClienteRepository();

  final ClienteRepository _clienteRepository;

  List<CreditoModel> _creditos = [];
  bool _isLoading = true;
  bool _isPaying = false;
  String? _error;
  RealtimeChannel? _creditosChannel;

  List<CreditoModel> get creditos => _creditos;
  bool get isLoading => _isLoading;
  bool get isPaying => _isPaying;
  String? get error => _error;

  void startListening() {
    _creditosChannel?.unsubscribe();
    _creditosChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-creditos-list',
      table: 'creditos',
      onChange: loadCreditos,
    );
  }

  Future<void> loadCreditos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _creditos = await _clienteRepository.fetchCreditos();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> pagarCuota({
    required String creditoId,
    required double monto,
    required String metodoPago,
  }) async {
    _isPaying = true;
    _error = null;
    notifyListeners();

    try {
      final pagoId = await _clienteRepository.registrarPagoCredito(
        creditoId: creditoId,
        monto: monto,
        metodoPago: metodoPago,
      );
      await loadCreditos();
      return pagoId;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isPaying = false;
      notifyListeners();
    }
  }

  Future<bool> confirmarPagoPendiente(String pagoId) async {
    _isPaying = true;
    _error = null;
    notifyListeners();

    try {
      await _clienteRepository.confirmarPagoCredito(pagoId);
      await loadCreditos();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isPaying = false;
      notifyListeners();
    }
  }

  Future<bool> pagarCuotaSimulada({
    required String creditoId,
    required double monto,
  }) async {
    _isPaying = true;
    _error = null;
    notifyListeners();

    try {
      await _clienteRepository.registrarPagoSimulado(
        creditoId: creditoId,
        monto: monto,
      );
      await loadCreditos();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isPaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    RealtimeHelper.unsubscribe(_creditosChannel);
    super.dispose();
  }
}
