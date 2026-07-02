import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/realtime_helper.dart';
import '../../data/clientes/cliente_repository.dart';
import '../../data/solicitudes/solicitud_repository.dart';
import '../../domain/models/solicitud_model.dart';

enum CreditoTabEntryKind { creditoVigente, solicitudAprobada }

class CreditoTabEntry {
  const CreditoTabEntry.credito(this.credito)
    : kind = CreditoTabEntryKind.creditoVigente,
      solicitud = null;

  const CreditoTabEntry.solicitud(this.solicitud)
    : kind = CreditoTabEntryKind.solicitudAprobada,
      credito = null;

  final CreditoTabEntryKind kind;
  final CreditoModel? credito;
  final SolicitudModel? solicitud;
}

class CreditsViewModel extends ChangeNotifier {
  CreditsViewModel({
    ClienteRepository? clienteRepository,
    SolicitudRepository? solicitudRepository,
  }) : _clienteRepository = clienteRepository ?? ClienteRepository(),
       _solicitudRepository = solicitudRepository ?? SolicitudRepository();

  final ClienteRepository _clienteRepository;
  final SolicitudRepository _solicitudRepository;

  List<CreditoTabEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _creditosChannel;
  RealtimeChannel? _solicitudesChannel;

  List<CreditoTabEntry> get entries => _entries;
  List<CreditoModel> get creditos => _entries
      .where((e) => e.kind == CreditoTabEntryKind.creditoVigente)
      .map((e) => e.credito!)
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _entries.isEmpty;

  void startListening() {
    _creditosChannel?.unsubscribe();
    _solicitudesChannel?.unsubscribe();
    _creditosChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-creditos-list',
      table: 'creditos',
      onChange: loadCreditos,
    );
    _solicitudesChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-solicitudes-creditos',
      table: 'solicitudes_credito',
      onChange: loadCreditos,
    );
  }

  Future<void> loadCreditos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _reloadEntries();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCreditos() async {
    try {
      await _reloadEntries();
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> _reloadEntries() async {
    final results = await Future.wait([
      _clienteRepository.fetchCreditos(),
      _solicitudRepository.fetchSolicitudesAprobadas(),
    ]);
    final creditos = results[0] as List<CreditoModel>;
    final solicitudes = results[1] as List<SolicitudModel>;

    _entries = [
      for (final s in solicitudes) CreditoTabEntry.solicitud(s),
      for (final c in creditos) CreditoTabEntry.credito(c),
    ];
  }

  Future<String?> pagarCuota({
    required String creditoId,
    required double monto,
    required String metodoPago,
  }) async {
    _error = null;

    try {
      final pagoId = await _clienteRepository.registrarPagoCredito(
        creditoId: creditoId,
        monto: monto,
        metodoPago: metodoPago,
      );
      return pagoId;
    } catch (error) {
      _error = error.toString();
      return null;
    }
  }

  Future<bool> confirmarPagoPendiente(String pagoId) async {
    _error = null;

    try {
      await _clienteRepository.confirmarPagoCredito(pagoId);
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    }
  }

  Future<bool> pagarCuotaSimulada({
    required String creditoId,
    required double monto,
  }) async {
    _error = null;

    try {
      await _clienteRepository.registrarPagoSimulado(
        creditoId: creditoId,
        monto: monto,
      );
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    }
  }

  @override
  void dispose() {
    RealtimeHelper.unsubscribe(_creditosChannel);
    RealtimeHelper.unsubscribe(_solicitudesChannel);
    super.dispose();
  }
}
