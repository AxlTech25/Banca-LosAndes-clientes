import 'package:flutter/foundation.dart';

import '../../data/auth/auth_repository.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  ForgotPasswordViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  PasswordRecoveryHint? _hint;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _sent = false;
  String? _error;

  PasswordRecoveryHint? get hint => _hint;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get sent => _sent;
  String? get error => _error;

  Future<void> lookupDni(String dni) async {
    _isLoading = true;
    _error = null;
    _sent = false;
    notifyListeners();

    try {
      _hint = await _authRepository.fetchRecoveryHint(dni);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendReset(String dni) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.requestPasswordReset(dni);
      _sent = true;
      return true;
    } on AuthFailure catch (error) {
      _error = error.message;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
