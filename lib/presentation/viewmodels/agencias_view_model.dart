import 'package:flutter/material.dart';

import '../../data/agencias/agencia_repository.dart';
import '../../domain/models/agencia_model.dart';

class AgenciasViewModel extends ChangeNotifier {
  AgenciasViewModel({AgenciaRepository? repository})
    : _repository = repository ?? AgenciaRepository();

  final AgenciaRepository _repository;

  List<AgenciaModel> _agencias = [];
  bool _isLoading = true;
  String? _error;

  List<AgenciaModel> get agencias => _agencias;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _agencias = await _repository.fetchAgenciasActivas();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
