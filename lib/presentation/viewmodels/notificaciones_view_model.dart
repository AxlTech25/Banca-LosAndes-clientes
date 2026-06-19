import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/notificaciones/notificacion_repository.dart';

class NotificacionesViewModel extends ChangeNotifier {
  NotificacionesViewModel({NotificacionRepository? repository})
    : _repository = repository ?? NotificacionRepository();

  final NotificacionRepository _repository;

  List<NotificacionModel> _notificaciones = [];
  int _noLeidas = 0;
  bool _isLoading = true;
  RealtimeChannel? _channel;

  List<NotificacionModel> get notificaciones => _notificaciones;
  int get noLeidas => _noLeidas;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchNotificaciones(),
        _repository.contarNoLeidas(),
      ]);
      _notificaciones = results[0] as List<NotificacionModel>;
      _noLeidas = results[1] as int;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBadge() async {
    _noLeidas = await _repository.contarNoLeidas();
    notifyListeners();
  }

  void startListening() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeNotificaciones(onChange: () {
      load();
    });
  }

  Future<void> marcarLeida(NotificacionModel notificacion) async {
    if (notificacion.leida) return;
    await _repository.marcarLeida(notificacion.id);
    await load();
  }

  Future<void> marcarTodasLeidas() async {
    await _repository.marcarTodasLeidas();
    await load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
