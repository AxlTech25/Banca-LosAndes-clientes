import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/fase4_models.dart';

/// La tabla `mensajes_solicitud` no existe en Supabase.
class ChatNoDisponibleException implements Exception {
  const ChatNoDisponibleException();

  @override
  String toString() =>
      'El chat no esta disponible. Ejecuta en Supabase SQL Editor el archivo '
      'supabase/migrations/008_fase4_pagos_firma_chat_buro.sql (seccion de chat).';
}

bool _esTablaChatFaltante(PostgrestException error) {
  final msg = error.message.toLowerCase();
  return msg.contains('mensajes_solicitud') &&
      (msg.contains('could not find') ||
          msg.contains('does not exist') ||
          msg.contains('schema cache'));
}

class MensajeRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<List<MensajeSolicitudModel>> fetchMensajes(String solicitudId) async {
    try {
      final rows = await _client
          .from('mensajes_solicitud')
          .select('id, solicitud_id, autor_tipo, contenido, created_at')
          .eq('solicitud_id', solicitudId)
          .order('created_at', ascending: true);
      return rows.map(MensajeSolicitudModel.fromMap).toList();
    } on PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) {
        throw const ChatNoDisponibleException();
      }
      return [];
    }
  }

  Future<MensajeSolicitudModel?> enviarMensaje({
    required String solicitudId,
    required String clienteId,
    required String contenido,
  }) async {
    try {
      final row = await _client
          .from('mensajes_solicitud')
          .insert({
            'solicitud_id': solicitudId,
            'cliente_id': clienteId,
            'autor_tipo': 'cliente',
            'contenido': contenido.trim(),
            'leido_cliente': true,
            'leido_asesor': false,
          })
          .select('id, solicitud_id, autor_tipo, contenido, created_at')
          .single();
      return MensajeSolicitudModel.fromMap(row);
    } on PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) {
        throw const ChatNoDisponibleException();
      }
      throw Exception(error.message);
    }
  }

  Future<void> marcarLeidosCliente(String solicitudId) async {
    try {
      await _client
          .from('mensajes_solicitud')
          .update({'leido_cliente': true})
          .eq('solicitud_id', solicitudId)
          .eq('autor_tipo', 'asesor')
          .eq('leido_cliente', false);
    } on PostgrestException catch (error) {
      if (_esTablaChatFaltante(error)) return;
    }
  }

  RealtimeChannel subscribeMensajes({
    required String solicitudId,
    required void Function() onChange,
  }) {
    return _client
        .channel('mensajes-$solicitudId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mensajes_solicitud',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'solicitud_id',
            value: solicitudId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
