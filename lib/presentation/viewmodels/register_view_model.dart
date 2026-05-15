import 'package:flutter/foundation.dart';

class RegisterViewModel extends ChangeNotifier {
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
    required String email,
    required String password,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 550));

    _isSubmitting = false;
    notifyListeners();
  }
}
