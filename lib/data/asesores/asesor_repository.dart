import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/asesor_cliente_model.dart';

class AsesorRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<AsesorClienteModel?> fetchAsesorPrincipal() async {
    try {
      final result = await _client.rpc('cliente_asesor_principal');
      if (result == null) return null;
      if (result is Map<String, dynamic>) {
        return AsesorClienteModel.fromMap(result);
      }
      if (result is Map) {
        return AsesorClienteModel.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
      return null;
    } on PostgrestException {
      return null;
    }
  }
}
