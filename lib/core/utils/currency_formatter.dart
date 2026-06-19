abstract final class CurrencyFormatter {
  static String pen(num? amount) {
    if (amount == null) return 'S/ 0.00';
    return 'S/ ${amount.toStringAsFixed(2)}';
  }
}
