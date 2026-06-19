import 'package:flutter/foundation.dart';

import '../../data/auth/auth_repository.dart';

class ChangePasswordViewModel extends ChangeNotifier {
  ChangePasswordViewModel({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<bool> changePassword(String newPassword) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _authRepository.updatePassword(newPassword);
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
