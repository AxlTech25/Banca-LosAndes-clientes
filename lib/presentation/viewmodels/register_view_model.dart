import 'package:flutter/foundation.dart';

import '../../data/auth/auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  bool _passwordVisible = false;
  bool _isSubmitting = false;

  bool get passwordVisible => _passwordVisible;
  bool get isSubmitting => _isSubmitting;

  void togglePasswordVisibility() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  Future<void> createAccount({
    required String fullName,
    required String dni,
    required String password,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _authRepository.signUpClient(
        fullName: fullName,
        dni: dni,
        password: password,
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
