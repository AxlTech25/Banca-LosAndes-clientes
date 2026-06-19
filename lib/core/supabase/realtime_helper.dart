import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

abstract final class RealtimeHelper {
  static RealtimeChannel subscribeTable({
    required String channelName,
    required String table,
    required void Function() onChange,
  }) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }

    return Supabase.instance.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static void unsubscribe(RealtimeChannel? channel) {
    channel?.unsubscribe();
  }
}
