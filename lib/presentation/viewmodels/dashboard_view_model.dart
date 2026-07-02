import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/realtime_helper.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/clientes/cliente_repository.dart';
import '../../data/solicitudes/solicitud_repository.dart';
import '../../domain/models/solicitud_model.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    AuthRepository? authRepository,
    ClienteRepository? clienteRepository,
    SolicitudRepository? solicitudRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _clienteRepository = clienteRepository ?? ClienteRepository(),
       _solicitudRepository = solicitudRepository ?? SolicitudRepository();

  final AuthRepository _authRepository;
  final ClienteRepository _clienteRepository;
  final SolicitudRepository _solicitudRepository;

  String _customerName = 'Cliente';
  String _availableBalance = 'S/ 0.00';
  String _nextPaymentLabel = 'Sin credito activo';
  String _pendingAmount = 'S/ 0.00';
  CreditoModel? _creditoActivo;
  SolicitudModel? _solicitudCompromiso;
  CronogramaCuotaModel? _proximaCuota;
  List<PreaprobadoModel> _preaprobados = [];
  List<CampanaModel> _campanas = [];
  bool _isLoading = true;
  bool _initialLoadComplete = false;
  RealtimeChannel? _creditosChannel;
  RealtimeChannel? _solicitudesChannel;

  bool get isInitialLoading => !_initialLoadComplete && _isLoading;
  bool get isRefreshing => _initialLoadComplete && _isLoading;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos dias,';
    if (hour < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  String get customerName => _customerName;
  String get accountName => 'Cuenta de Ahorros';
  String get availableBalance => _availableBalance;
  String get nextPaymentLabel => _nextPaymentLabel;
  String get pendingAmount => _pendingAmount;
  bool get isLoading => _isLoading;
  bool get hasCreditoActivo => _creditoActivo != null || _solicitudCompromiso != null;
  bool get enMora => _creditoActivo?.enMora ?? false;
  int get diasMora => _creditoActivo?.diasMora ?? 0;
  String? get creditoActivoId => _creditoActivo?.id;
  String? get solicitudCompromisoId => _solicitudCompromiso?.id;
  List<PreaprobadoModel> get preaprobados => _preaprobados;
  List<CampanaModel> get campanas => _campanas;
  bool get hasOfertas => _preaprobados.isNotEmpty || _campanas.isNotEmpty;

  bool get canPagarCuota {
    final credito = _creditoActivo;
    if (credito == null || !credito.isVigente) return false;
    return (credito.saldoActual ?? 0) > 0 && cuotaPagoMonto > 0;
  }

  double get cuotaPagoMonto {
    if (_proximaCuota != null && _proximaCuota!.montoCuota > 0) {
      return _proximaCuota!.montoCuota;
    }
    final cuotaSolicitud = _solicitudCompromiso?.cuotaMensualMostrada;
    if (cuotaSolicitud != null && cuotaSolicitud > 0) {
      return cuotaSolicitud.toDouble();
    }
    return _creditoActivo?.cuotaEstimada.toDouble() ?? 0;
  }

  String get cuotaPagoLabel => ClienteRepository.formatBalance(cuotaPagoMonto);

  void startListening() {
    _creditosChannel?.unsubscribe();
    _solicitudesChannel?.unsubscribe();
    _creditosChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-creditos-home',
      table: 'creditos',
      onChange: loadDashboard,
    );
    _solicitudesChannel = RealtimeHelper.subscribeTable(
      channelName: 'client-solicitudes-home',
      table: 'solicitudes_credito',
      onChange: loadDashboard,
    );
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final critical = await Future.wait([
        _authRepository.fetchCurrentCliente(),
        _clienteRepository.fetchCuentaAhorros(),
        _clienteRepository.fetchCreditoVigente(),
        _solicitudRepository.fetchSolicitudesAprobadas(),
      ]);

      final cliente = critical[0] as Map<String, dynamic>?;
      final cuenta = critical[1] as Map<String, dynamic>?;
      final credito = critical[2] as CreditoModel?;
      final solicitudes = critical[3] as List<SolicitudModel>;

      final nombres = cliente?['nombres']?.toString().trim() ?? '';
      final apellidos = cliente?['apellidos']?.toString().trim() ?? '';
      final fullName = [nombres, apellidos]
          .where((part) => part.isNotEmpty)
          .join(' ');

      if (fullName.isNotEmpty) _customerName = fullName;

      final saldo = _parseNum(cuenta?['saldo_disponible']);
      _availableBalance = ClienteRepository.formatBalance(saldo);

      _creditoActivo = credito;
      _solicitudCompromiso = solicitudes.isNotEmpty ? solicitudes.first : null;
      _proximaCuota = null;

      if (_solicitudCompromiso != null) {
        final cronograma =
            await _solicitudRepository.fetchCronograma(_solicitudCompromiso!);
        final cuotasPagadas = _creditoActivo?.cuotasPagadas ?? 0;
        if (cronograma.isNotEmpty && cuotasPagadas < cronograma.length) {
          _proximaCuota = cronograma[cuotasPagadas];
        }
      }

      _applyCompromisoLabels();

      _initialLoadComplete = true;
      _isLoading = false;
      notifyListeners();

      final offers = await Future.wait([
        _solicitudRepository.fetchPreaprobados(),
        _solicitudRepository.fetchCampanas(),
      ]);
      _preaprobados = offers[0] as List<PreaprobadoModel>;
      _campanas = offers[1] as List<CampanaModel>;
      notifyListeners();
    } catch (_) {
      _initialLoadComplete = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyCompromisoLabels() {
    if (_creditoActivo != null) {
      if (_proximaCuota != null) {
        _nextPaymentLabel =
            'Cuota ${_proximaCuota!.numeroCuota} · ${_formatFecha(_proximaCuota!.fechaPago)}';
        _pendingAmount = ClienteRepository.formatBalance(_proximaCuota!.montoCuota);
      } else {
        _nextPaymentLabel =
            ClienteRepository.buildNextPaymentLabel(_creditoActivo);
        _pendingAmount =
            ClienteRepository.formatBalance(_creditoActivo!.cuotaEstimada);
      }
      return;
    }

    if (_solicitudCompromiso != null) {
      final solicitud = _solicitudCompromiso!;
      if (_proximaCuota != null) {
        _nextPaymentLabel =
            'Cuota ${_proximaCuota!.numeroCuota} · ${_formatFecha(_proximaCuota!.fechaPago)}';
        _pendingAmount =
            ClienteRepository.formatBalance(_proximaCuota!.montoCuota);
      } else {
        _nextPaymentLabel = solicitud.estado == 'aprobada'
            ? 'Credito aprobado · pendiente de activacion'
            : 'Cronograma disponible';
        _pendingAmount = ClienteRepository.formatBalance(
          solicitud.cuotaMensualMostrada,
        );
      }
      return;
    }

    _nextPaymentLabel = 'Sin credito activo';
    _pendingAmount = 'S/ 0.00';
  }

  String _formatFecha(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  Future<void> signOut() => _authRepository.signOut();

  @override
  void dispose() {
    RealtimeHelper.unsubscribe(_creditosChannel);
    RealtimeHelper.unsubscribe(_solicitudesChannel);
    super.dispose();
  }
}
