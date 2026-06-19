import 'package:flutter/foundation.dart';

import '../../data/auth/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  bool _rememberUser = false;
  bool _passwordVisible = false;
  bool _isSubmitting = false;

  bool get rememberUser => _rememberUser;
  bool get passwordVisible => _passwordVisible;
  bool get isSubmitting => _isSubmitting;

  void setRememberUser(bool value) {
    if (_rememberUser == value) return;
    _rememberUser = value;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  Future<void> signIn({required String dni, required String password}) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _authRepository.signInWithDni(dni: dni, password: password);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
