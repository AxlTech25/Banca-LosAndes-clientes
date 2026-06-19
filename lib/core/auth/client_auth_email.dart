abstract final class ClientAuthEmail {
  static const String domain = 'clientes.bancolosandes.pe';

  static String fromDni(String dni) {
    final normalized = dni.trim();
    return '$normalized@$domain';
  }
}
