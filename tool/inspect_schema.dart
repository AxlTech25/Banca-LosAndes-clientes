import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final env = await _loadEnv('.env');
  final client = SupabaseClient(
    env['SUPABASE_URL']!.trim(),
    env['SUPABASE_ANON_KEY']!.trim(),
  );

  stdout.writeln('=== clientes (muestra columnas via select *) ===');
  try {
    final row = await client.from('clientes').select('*').limit(1);
    if (row.isEmpty) {
      stdout.writeln('Tabla vacia. Columnas conocidas por insert de prueba omitido.');
    } else {
      stdout.writeln(row.first.keys.join(', '));
    }
  } catch (e) {
    stdout.writeln('ERR: $e');
  }

  stdout.writeln('\n=== solicitudes_credito ===');
  try {
    final row = await client.from('solicitudes_credito').select('*').limit(1);
    stdout.writeln(row.isEmpty ? 'Tabla vacia' : row.first.keys.join(', '));
  } catch (e) {
    stdout.writeln('ERR: $e');
  }

  stdout.writeln('\n=== Funciones RPC disponibles (prueba) ===');
  final rpcs = [
    'current_asesor_perfil',
    'cliente_id_actual',
    'vincular_cliente_registro',
    'registrar_pago_simulado',
    'ensure_asesor_profile',
  ];
  for (final rpc in rpcs) {
    try {
      await client.rpc(rpc);
      stdout.writeln('OK  $rpc');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Could not find the function')) {
        stdout.writeln('NO  $rpc');
      } else {
        stdout.writeln('OK  $rpc (existe)');
      }
    }
  }

  stdout.writeln('\n=== Verificar columnas nuevas en clientes ===');
  for (final col in ['user_id', 'token_fcm']) {
    try {
      await client.from('clientes').select(col).limit(1);
      stdout.writeln('OK  clientes.$col');
    } catch (e) {
      stdout.writeln('NO  clientes.$col');
    }
  }

  stdout.writeln('\n=== Verificar solicitudes_credito.origen ===');
  try {
    await client.from('solicitudes_credito').select('origen').limit(1);
    stdout.writeln('OK  solicitudes_credito.origen');
  } catch (e) {
    stdout.writeln('NO  solicitudes_credito.origen');
  }
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  final env = <String, String>{};
  for (final line in await file.readAsLines()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final i = trimmed.indexOf('=');
    if (i > 0) env[trimmed.substring(0, i).trim()] = trimmed.substring(i + 1).trim();
  }
  return env;
}
