import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final env = await _loadEnv('.env');
  final url = env['SUPABASE_URL']?.trim() ?? '';
  final key = env['SUPABASE_ANON_KEY']?.trim() ?? '';

  if (url.isEmpty || key.isEmpty) {
    stderr.writeln('ERROR: SUPABASE_URL o SUPABASE_ANON_KEY faltan en .env');
    exit(1);
  }

  final client = SupabaseClient(url, key);
  stdout.writeln('Conectando a: $url\n');

  final tables = [
    'agencias',
    'asesores_negocio',
    'clientes',
    'creditos',
    'creditos_preaprobados',
    'campanas_activas',
    'cartera_diaria',
    'cartera_vencida',
    'solicitudes_credito',
    'solicitudes_documentos',
    'consultas_buro',
    'acciones_cobranza',
    'alertas_cartera',
    'solicitudes_notas_internas',
    'cuentas',
    'pagos_credito',
    'solicitudes_historial_estado',
  ];

  stdout.writeln('=== TABLAS ===');
  for (final table in tables) {
    try {
      final rows = await client.from(table).select('id').limit(1);
      final count = await _countRows(url, key, table);
      stdout.writeln('OK  $table ($count filas)');
    } catch (error) {
      stdout.writeln('ERR $table -> $error');
    }
  }

  stdout.writeln('\n=== COLUMNAS clientes ===');
  await _printColumns(url, key, 'clientes');

  stdout.writeln('\n=== RPC ===');
  for (final fn in [
    'cliente_id_actual',
    'vincular_cliente_registro',
    'registrar_pago_simulado',
  ]) {
    try {
      await client.rpc(fn);
      stdout.writeln('OK  $fn (existe)');
    } catch (error) {
      final message = error.toString();
      if (message.contains('permission denied') ||
          message.contains('JWT') ||
          message.contains('null')) {
        stdout.writeln('OK  $fn (existe, requiere auth)');
      } else {
        stdout.writeln('ERR $fn -> $message');
      }
    }
  }

  stdout.writeln('\nListo.');
}

Future<String> _countRows(String url, String key, String table) async {
  final response = await http.get(
    Uri.parse('$url/rest/v1/$table?select=id'),
    headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Prefer': 'count=exact',
      'Range-Unit': 'items',
      'Range': '0-0',
    },
  );

  final range = response.headers['content-range'];
  if (range != null && range.contains('/')) {
    return range.split('/').last;
  }
  return '?';
}

Future<void> _printColumns(String url, String key, String table) async {
  final response = await http.get(
    Uri.parse('$url/rest/v1/?select=*'),
    headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Accept': 'application/openapi+json',
    },
  );

  if (response.statusCode != 200) {
    stdout.writeln('No se pudo leer OpenAPI (${response.statusCode})');
    return;
  }

  final spec = jsonDecode(response.body) as Map<String, dynamic>;
  final definitions = spec['definitions'] as Map<String, dynamic>? ?? {};
  final tableDef = definitions[table] as Map<String, dynamic>?;
  if (tableDef == null) {
    stdout.writeln('Tabla $table no encontrada en OpenAPI');
    return;
  }

  final props = tableDef['properties'] as Map<String, dynamic>? ?? {};
  for (final entry in props.entries) {
    stdout.writeln('  - ${entry.key}');
  }
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) return {};

  final lines = await file.readAsLines();
  final env = <String, String>{};
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    env[trimmed.substring(0, index).trim()] = trimmed
        .substring(index + 1)
        .trim();
  }
  return env;
}
