import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/agencia_model.dart';

class AgenciaRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<List<AgenciaModel>> fetchAgenciasActivas() async {
    try {
      final rows = await _client
          .from('agencias')
          .select('id, nombre, region, lat, lng')
          .eq('activa', true)
          .order('nombre');
      return rows.map(AgenciaModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }
}
