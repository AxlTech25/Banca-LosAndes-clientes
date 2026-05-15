import 'package:flutter/foundation.dart';

class DashboardViewModel extends ChangeNotifier {
  String get greeting => 'Buenos d\u00edas,';
  String get customerName => 'Juan P\u00e9rez';
  String get accountName => 'Cuenta de Ahorros';
  String get availableBalance => r'$1,250.00';
  String get nextPaymentLabel => 'Pr\u00f3ximo pago en 5 d\u00edas';
  String get pendingAmount => r'$450.00';
}
