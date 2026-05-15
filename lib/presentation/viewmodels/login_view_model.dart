import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
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

  Future<void> signIn({required String user, required String password}) async {
    _isSubmitting = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 450));

    _isSubmitting = false;
    notifyListeners();
  }
}
