import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/fase4_models.dart';

class BuroRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<BuroResumidoModel?> fetchResumen() async {
    try {
      final result = await _client.rpc('cliente_buro_resumido');
      if (result == null) return null;
      if (result is Map<String, dynamic>) {
        return BuroResumidoModel.fromMap(result);
      }
      if (result is Map) {
        return BuroResumidoModel.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PostgrestException {
      return null;
    }
  }
}
