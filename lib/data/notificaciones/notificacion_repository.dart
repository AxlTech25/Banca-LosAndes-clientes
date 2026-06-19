import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';

class NotificacionModel {
  const NotificacionModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    this.referenciaTipo,
    this.referenciaId,
    this.leida = false,
    this.createdAt,
  });

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    return NotificacionModel(
      id: map['id']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      titulo: map['titulo']?.toString() ?? '',
      mensaje: map['mensaje']?.toString() ?? '',
      referenciaTipo: map['referencia_tipo']?.toString(),
      referenciaId: map['referencia_id']?.toString(),
      leida: map['leida'] as bool? ?? false,
      createdAt: map['created_at']?.toString(),
    );
  }

  final String id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final String? referenciaTipo;
  final String? referenciaId;
  final bool leida;
  final String? createdAt;
}

class NotificacionRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<List<NotificacionModel>> fetchNotificaciones() async {
    try {
      final rows = await _client
          .from('notificaciones_cliente')
          .select(
            'id, tipo, titulo, mensaje, referencia_tipo, referencia_id, leida, created_at',
          )
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map(NotificacionModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<int> contarNoLeidas() async {
    try {
      final rows = await _client
          .from('notificaciones_cliente')
          .select('id')
          .eq('leida', false);
      return rows.length;
    } on PostgrestException {
      return 0;
    }
  }

  Future<void> marcarLeida(String id) async {
    await _client
        .from('notificaciones_cliente')
        .update({'leida': true})
        .eq('id', id);
  }

  Future<void> marcarTodasLeidas() async {
    await _client
        .from('notificaciones_cliente')
        .update({'leida': true})
        .eq('leida', false);
  }

  RealtimeChannel subscribeNotificaciones({
    required void Function() onChange,
  }) {
    return _client
        .channel('notificaciones_cliente_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_cliente',
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
