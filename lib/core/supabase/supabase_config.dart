import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static const String _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKeyFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get url {
    return dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_URL']!.trim()
        : _urlFromDefine;
  }

  static String get anonKey {
    return dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_ANON_KEY']!.trim()
        : _anonKeyFromDefine;
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    if (!isConfigured) return;

    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
