import 'package:flutter/foundation.dart';

import '../../data/asesores/asesor_repository.dart';
import '../../domain/models/asesor_cliente_model.dart';

class MiAsesorViewModel extends ChangeNotifier {
  MiAsesorViewModel({AsesorRepository? repository})
    : _repository = repository ?? AsesorRepository();

  final AsesorRepository _repository;

  AsesorClienteModel? _asesor;
  bool _isLoading = true;
  String? _error;

  AsesorClienteModel? get asesor => _asesor;
  bool get isLoading => _isLoading;
  bool get hasAsesor => _asesor != null;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _asesor = await _repository.fetchAsesorPrincipal();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
