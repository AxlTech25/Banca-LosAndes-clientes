import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/mensajes/mensaje_repository.dart';
import '../../domain/models/fase4_models.dart';

class ChatSolicitudViewModel extends ChangeNotifier {
  ChatSolicitudViewModel({
    required this.solicitudId,
    MensajeRepository? repository,
    AuthRepository? authRepository,
  }) : _repository = repository ?? MensajeRepository(),
       _authRepository = authRepository ?? AuthRepository();

  final String solicitudId;
  final MensajeRepository _repository;
  final AuthRepository _authRepository;

  List<MensajeSolicitudModel> _mensajes = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _chatNoDisponible = false;
  String? _error;
  String? _clienteId;
  RealtimeChannel? _channel;

  List<MensajeSolicitudModel> get mensajes => _mensajes;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get chatNoDisponible => _chatNoDisponible;
  String? get error => _error;

  void startListening() {
    _channel?.unsubscribe();
    _channel = _repository.subscribeMensajes(
      solicitudId: solicitudId,
      onChange: load,
    );
  }

  Future<void> load() async {
    _isLoading = _mensajes.isEmpty;
    _error = null;
    notifyListeners();

    try {
      _clienteId ??= (await _authRepository.fetchCurrentCliente())?['id']
          ?.toString();
      _mensajes = await _repository.fetchMensajes(solicitudId);
      await _repository.marcarLeidosCliente(solicitudId);
    } catch (error) {
      if (error is ChatNoDisponibleException) {
        _chatNoDisponible = true;
        _error = error.toString();
      } else {
        _error = error.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> enviar(String contenido) async {
    final clienteId = _clienteId;
    if (clienteId == null) return false;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.enviarMensaje(
        solicitudId: solicitudId,
        clienteId: clienteId,
        contenido: contenido,
      );
      await load();
      return true;
    } catch (error) {
      if (error is ChatNoDisponibleException) {
        _chatNoDisponible = true;
      }
      _error = error.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
