import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/client_auth_email.dart';
import '../../core/supabase/supabase_config.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class PasswordRecoveryHint {
  const PasswordRecoveryHint({
    required this.found,
    this.emailMasked,
    this.telefonoMasked,
  });

  final bool found;
  final String? emailMasked;
  final String? telefonoMasked;
}

class AuthRepository {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthFailure(
        'Configura SUPABASE_URL y SUPABASE_ANON_KEY para usar autenticacion.',
      );
    }

    return Supabase.instance.client;
  }

  User? get currentUser {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  Future<void> signInWithDni({
    required String dni,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: ClientAuthEmail.fromDni(dni),
        password: password,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error.message));
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('No se pudo iniciar sesion. Intenta nuevamente.');
    }
  }

  Future<void> signUpClient({
    required String fullName,
    required String dni,
    required String password,
    String? email,
    String? telefono,
    String? tipoNegocio,
    String? nombreNegocio,
    String? ubicacionNegocio,
    int? antiguedadMeses,
    double? ingresosEstimados,
    double? gastosMensuales,
  }) async {
    final nameParts = _splitFullName(fullName);
    final normalizedDni = dni.trim();

    try {
      final response = await _client.auth.signUp(
        email: ClientAuthEmail.fromDni(normalizedDni),
        password: password,
        data: {
          'dni': normalizedDni,
          'nombres': nameParts.$1,
          'apellidos': nameParts.$2,
          'rol': 'cliente',
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AuthFailure('No se pudo crear el usuario.');
      }

      if (response.session == null) {
        final signInResponse = await _client.auth.signInWithPassword(
          email: ClientAuthEmail.fromDni(normalizedDni),
          password: password,
        );
        if (signInResponse.session == null) {
          throw const AuthFailure(
            'Cuenta creada. Confirma tu correo o desactiva la confirmacion en Supabase.',
          );
        }
      }

      await _linkClientProfile(
        dni: normalizedDni,
        nombres: nameParts.$1,
        apellidos: nameParts.$2,
        email: email,
        telefono: telefono,
      );

      if (tipoNegocio != null &&
          nombreNegocio != null &&
          ubicacionNegocio != null &&
          antiguedadMeses != null &&
          ingresosEstimados != null &&
          gastosMensuales != null) {
        await savePerfilNegocio(
          tipoNegocio: tipoNegocio,
          nombreNegocio: nombreNegocio,
          ubicacionNegocio: ubicacionNegocio,
          antiguedadMeses: antiguedadMeses,
          ingresosEstimados: ingresosEstimados,
          gastosMensuales: gastosMensuales,
        );
      }
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(
        'Usuario creado, pero no se pudo guardar el perfil: ${error.message}',
      );
    } on AuthFailure {
      rethrow;
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw const AuthFailure('No se pudo completar el registro.');
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentCliente() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await _client
          .from('clientes')
          .select(
            'id, nombres, apellidos, numero_documento, email, telefono, '
            'tipo_negocio, nombre_negocio, antiguedad_negocio_meses, ingresos_estimados, '
            'gastos_mensuales, direccion, calificacion_sbs',
          )
          .eq('user_id', user.id)
          .maybeSingle();
    } on PostgrestException {
      return null;
    }
  }

  Future<void> savePerfilNegocio({
    required String tipoNegocio,
    required String nombreNegocio,
    required String ubicacionNegocio,
    required int antiguedadMeses,
    required double ingresosEstimados,
    required double gastosMensuales,
  }) async {
    try {
      await _client.rpc(
        'actualizar_perfil_negocio_cliente',
        params: {
          'p_tipo_negocio': tipoNegocio,
          'p_nombre_negocio': nombreNegocio,
          'p_ubicacion_negocio': ubicacionNegocio,
          'p_antiguedad_meses': antiguedadMeses,
          'p_ingresos_estimados': ingresosEstimados,
          'p_gastos_mensuales': gastosMensuales,
        },
      );
    } on PostgrestException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client.auth.signOut();
  }

  Future<PasswordRecoveryHint> fetchRecoveryHint(String dni) async {
    try {
      final result = await _client.rpc(
        'cliente_hint_recuperacion',
        params: {'p_dni': dni.trim()},
      );
      if (result is! Map) {
        return const PasswordRecoveryHint(found: false);
      }
      final map = Map<String, dynamic>.from(result);
      return PasswordRecoveryHint(
        found: map['found'] == true,
        emailMasked: map['email_masked']?.toString(),
        telefonoMasked: map['telefono_masked']?.toString(),
      );
    } on PostgrestException {
      return const PasswordRecoveryHint(found: false);
    }
  }

  Future<void> requestPasswordReset(String dni) async {
    try {
      await _client.auth.resetPasswordForEmail(
        ClientAuthEmail.fromDni(dni),
      );
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error.message));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error.message));
    }
  }

  Future<void> _linkClientProfile({
    required String dni,
    required String nombres,
    required String apellidos,
    String? email,
    String? telefono,
  }) async {
    await _client.rpc(
      'vincular_cliente_registro',
      params: {
        'p_dni': dni,
        'p_nombres': nombres,
        'p_apellidos': apellidos,
        'p_email': email,
        'p_telefono': telefono,
      },
    );
  }

  (String, String) _splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');
    return (firstName, lastName.isEmpty ? firstName : lastName);
  }

  String _mapAuthMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'DNI o contrasena incorrectos.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirma tu cuenta antes de iniciar sesion.';
    }
    if (normalized.contains('user already registered') ||
        normalized.contains('already registered')) {
      return 'Ya existe una cuenta con ese DNI.';
    }
    if (normalized.contains('password')) {
      return 'La contrasena no cumple los requisitos.';
    }
    if (normalized.contains('dni ya tiene una cuenta vinculada')) {
      return 'Este DNI ya tiene una cuenta vinculada.';
    }
    return message;
  }
}
