import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../../domain/models/solicitud_model.dart';
import '../auth/auth_repository.dart';

class SolicitudRepository {
  SolicitudRepository({
    AuthRepository? authRepository,
    SupabaseClient? client,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _client = client;

  final AuthRepository _authRepository;
  final SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) return _client!;
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<String?> _clienteId() async {
    final perfil = await _authRepository.fetchCurrentCliente();
    return perfil?['id']?.toString();
  }

  Future<List<SolicitudModel>> fetchSolicitudes() async {
    try {
      final rows = await client
          .from('solicitudes_credito')
          .select(
            'id, numero_expediente, estado, monto_solicitado, monto_aprobado, '
            'plazo_meses, destino_credito, nombre_negocio, tipo_negocio, '
            'motivo_rechazo, condicion_adicional, created_at, firma_cliente_base64',
          )
          .order('created_at', ascending: false);
      return rows.map(SolicitudModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<SolicitudModel?> fetchSolicitudById(String id) async {
    try {
      final row = await client
          .from('solicitudes_credito')
          .select(
            'id, numero_expediente, estado, monto_solicitado, monto_aprobado, '
            'plazo_meses, destino_credito, nombre_negocio, tipo_negocio, '
            'motivo_rechazo, condicion_adicional, created_at, firma_cliente_base64',
          )
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : SolicitudModel.fromMap(row);
    } on PostgrestException {
      return null;
    }
  }

  Future<List<HistorialEstadoModel>> fetchHistorial(String solicitudId) async {
    try {
      final rows = await client
          .from('solicitudes_historial_estado')
          .select(
            'estado_anterior, estado_nuevo, observacion, actor_tipo, created_at',
          )
          .eq('solicitud_id', solicitudId)
          .order('created_at', ascending: true);
      return rows.map(HistorialEstadoModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<List<PreaprobadoModel>> fetchPreaprobados() async {
    try {
      final rows = await client
          .from('creditos_preaprobados')
          .select(
            'id, monto_maximo, plazo_sugerido_meses, tea_referencial, fecha_vencimiento',
          )
          .eq('vigente', true)
          .order('created_at', ascending: false);
      return rows.map(PreaprobadoModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<List<CampanaModel>> fetchCampanas() async {
    try {
      final rows = await client
          .from('campanas_activas')
          .select('id, tipo_campana, monto_ofertado, fecha_vencimiento')
          .eq('activa', true)
          .order('created_at', ascending: false);
      return rows.map(CampanaModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<SolicitudModel> crearSolicitud(
    NuevaSolicitudInput input, {
    String? firmaBase64,
  }) async {
    final clienteId = await _clienteId();
    if (clienteId == null) {
      throw Exception('No se encontro tu perfil de cliente.');
    }

    final expediente =
        'SOL-C-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    try {
      final row = await client
          .from('solicitudes_credito')
          .insert({
            'cliente_id': clienteId,
            'origen': 'app_cliente',
            'estado': 'pendiente',
            'numero_expediente': expediente,
            'tipo_negocio': input.tipoNegocio,
            'nombre_negocio': input.nombreNegocio,
            'antiguedad_negocio_meses': input.antiguedadMeses,
            'ingresos_estimados': input.ingresosEstimados,
            'monto_solicitado': input.montoSolicitado,
            'plazo_meses': input.plazoMeses,
            'destino_credito': input.destinoCredito,
            'moneda': 'PEN',
            'tipo_cuota': 'mensual',
            if (firmaBase64 != null) 'firma_cliente_base64': firmaBase64,
          })
          .select(
            'id, numero_expediente, estado, monto_solicitado, monto_aprobado, '
            'plazo_meses, destino_credito, nombre_negocio, tipo_negocio, '
            'motivo_rechazo, condicion_adicional, created_at, firma_cliente_base64',
          )
          .single();
      return SolicitudModel.fromMap(row);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> guardarFirma({
    required String solicitudId,
    required String firmaBase64,
  }) async {
    try {
      await client.rpc(
        'guardar_firma_solicitud',
        params: {
          'p_solicitud_id': solicitudId,
          'p_firma_base64': firmaBase64,
        },
      );
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  static const _bucketDocumentos = 'documentos-solicitudes';

  Future<List<SolicitudDocumentoModel>> fetchDocumentos(String solicitudId) async {
    try {
      final rows = await client
          .from('solicitudes_documentos')
          .select('id, tipo_documento, storage_url, tamanio_kb, created_at')
          .eq('solicitud_id', solicitudId)
          .order('created_at', ascending: false);
      return rows.map(SolicitudDocumentoModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  Future<String> getDocumentoSignedUrl(String storagePath) async {
    return client.storage.from(_bucketDocumentos).createSignedUrl(
      storagePath,
      3600,
    );
  }

  Future<SolicitudDocumentoModel> subirDocumento({
    required String solicitudId,
    required String tipoDocumento,
    required Uint8List bytes,
    required String extension,
    required String mimeType,
  }) async {
    if (bytes.length > 1048576) {
      throw Exception('El archivo no debe superar 1 MB.');
    }

    final fileName =
        '${tipoDocumento.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$solicitudId/$fileName';

    try {
      await client.storage.from(_bucketDocumentos).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

      final tamanioKb = (bytes.length / 1024).ceil();

      final row = await client
          .from('solicitudes_documentos')
          .insert({
            'solicitud_id': solicitudId,
            'tipo_documento': tipoDocumento,
            'storage_url': path,
            'tamanio_kb': tamanioKb,
          })
          .select('id, tipo_documento, storage_url, tamanio_kb, created_at')
          .single();

      return SolicitudDocumentoModel.fromMap(row);
    } on StorageException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }
}
