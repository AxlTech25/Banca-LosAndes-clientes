import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/amortization_schedule.dart';
import '../../core/utils/credit_calculator.dart';
import '../../core/supabase/supabase_config.dart';
import '../../domain/models/credit_product_models.dart';
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
    if (_client != null) return _client;
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no configurado.');
    }
    return Supabase.instance.client;
  }

  Future<String?> _clienteId() async {
    final perfil = await _authRepository.fetchCurrentCliente();
    return perfil?['id']?.toString();
  }

  static const _solicitudSelect =
      'id, numero_expediente, estado, producto, monto_solicitado, monto_aprobado, '
      'plazo_meses, destino_credito, nombre_negocio, tipo_negocio, ubicacion_negocio, '
      'gastos_mensuales, garantia, tea_referencial, cuota_estimada, '
      'cuota_mensual_aprobada, fecha_desembolso_programada, '
      'motivo_rechazo, condicion_adicional, created_at, firma_cliente_base64';

  Future<List<SolicitudModel>> fetchSolicitudes() async {
    try {
      final rows = await client
          .from('solicitudes_credito')
          .select(_solicitudSelect)
          .order('created_at', ascending: false);
      return rows.map(SolicitudModel.fromMap).toList();
    } on PostgrestException {
      return [];
    }
  }

  /// Solicitudes con credito aprobado o desembolsado (pestaña Créditos del cliente).
  Future<List<SolicitudModel>> fetchSolicitudesAprobadas() async {
    try {
      final rows = await client
          .from('solicitudes_credito')
          .select(_solicitudSelect)
          .inFilter('estado', ['aprobada', 'desembolsada'])
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
          .select(_solicitudSelect)
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

  Future<List<CronogramaCuotaModel>> fetchCronograma(
    SolicitudModel solicitud,
  ) async {
    try {
      final rows = await client
          .from('solicitudes_cronograma_cuotas')
          .select(
            'numero_cuota, fecha_pago, monto_cuota, capital, interes, saldo',
          )
          .eq('solicitud_id', solicitud.id)
          .order('numero_cuota', ascending: true);
      final parsed = rows.map(CronogramaCuotaModel.fromMap).toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    } on PostgrestException {
      // Tabla aun no migrada: calcular en cliente.
    }

    return _cronogramaLocal(solicitud);
  }

  List<CronogramaCuotaModel> _cronogramaLocal(SolicitudModel solicitud) {
    if (!solicitud.muestraCronograma) return [];

    final monto =
        (solicitud.montoAprobado ?? solicitud.montoSolicitado)?.toDouble();
    final plazo = solicitud.plazoMeses;
    final tea = (solicitud.teaReferencial ??
            CreditoProducto.teaSinDesgravamen)
        .toDouble();
    if (monto == null || plazo == null || monto <= 0 || plazo <= 0) {
      return [];
    }

    DateTime? desembolso;
    final fechaStr = solicitud.fechaDesembolsoProgramada;
    if (fechaStr != null && fechaStr.isNotEmpty) {
      desembolso = DateTime.tryParse(fechaStr);
    }

    return AmortizationSchedule.generarFrances(
      monto: monto,
      plazoMeses: plazo,
      teaPercent: tea,
      fechaDesembolso: desembolso,
    ).map(
      (row) => CronogramaCuotaModel(
        numeroCuota: row.numero,
        fechaPago: row.fechaPago,
        montoCuota: row.cuota,
        capital: row.capital,
        interes: row.interes,
        saldo: row.saldo,
      ),
    ).toList();
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

    final tea = input.teaReferencial ?? input.teaAplicada;
    final cuota = input.cuotaEstimada ??
        CreditCalculator.cuotaFrancesa(
          monto: input.montoSolicitado,
          plazoMeses: input.plazoMeses,
          teaPercent: tea,
        );

    try {
      final row = await client
          .from('solicitudes_credito')
          .insert({
            'cliente_id': clienteId,
            'origen': 'app_cliente',
            'estado': 'pendiente',
            'numero_expediente': expediente,
            'producto': CreditoProducto.codigo,
            'tipo_negocio': input.tipoNegocio,
            'nombre_negocio': input.nombreNegocio,
            'ubicacion_negocio': input.ubicacionNegocio,
            'antiguedad_negocio_meses': input.antiguedadMeses,
            'ingresos_estimados': input.ingresosEstimados,
            'gastos_mensuales': input.gastosMensuales,
            'garantia': input.garantia,
            'monto_solicitado': input.montoSolicitado,
            'plazo_meses': input.plazoMeses,
            'destino_credito': input.destinoCredito,
            'tea_referencial': tea,
            'cuota_estimada': double.parse(cuota.toStringAsFixed(2)),
            'moneda': 'PEN',
            'tipo_cuota': 'mensual',
    if (firmaBase64 != null) 'firma_cliente_base64': firmaBase64,
          })
          .select(_solicitudSelect)
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
      return _deduplicarDocumentosPorTipo(
        rows.map(SolicitudDocumentoModel.fromMap).toList(),
      );
    } on PostgrestException {
      return [];
    }
  }

  static List<SolicitudDocumentoModel> _deduplicarDocumentosPorTipo(
    List<SolicitudDocumentoModel> documentos,
  ) {
    final vistos = <String>{};
    final resultado = <SolicitudDocumentoModel>[];
    for (final doc in documentos) {
      if (vistos.add(doc.tipoDocumento)) {
        resultado.add(doc);
      }
    }
    return resultado;
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

    final path = '$solicitudId/${tipoDocumento.toLowerCase()}.$extension';

    try {
      final existente = await client
          .from('solicitudes_documentos')
          .select('id, storage_url')
          .eq('solicitud_id', solicitudId)
          .eq('tipo_documento', tipoDocumento)
          .maybeSingle();

      await client.storage.from(_bucketDocumentos).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

      final tamanioKb = (bytes.length / 1024).ceil();
      final payload = {
        'solicitud_id': solicitudId,
        'tipo_documento': tipoDocumento,
        'storage_url': path,
        'tamanio_kb': tamanioKb,
      };

      final Map<String, dynamic> row;
      if (existente != null) {
        final anteriorPath = existente['storage_url']?.toString();
        if (anteriorPath != null &&
            anteriorPath.isNotEmpty &&
            anteriorPath != path) {
          try {
            await client.storage.from(_bucketDocumentos).remove([anteriorPath]);
          } on StorageException {
            // El reemplazo en BD sigue siendo valido aunque falle borrar el archivo anterior.
          }
        }

        row = await client
            .from('solicitudes_documentos')
            .update(payload)
            .eq('id', existente['id'])
            .select('id, tipo_documento, storage_url, tamanio_kb, created_at')
            .single();
      } else {
        row = await client
            .from('solicitudes_documentos')
            .insert(payload)
            .select('id, tipo_documento, storage_url, tamanio_kb, created_at')
            .single();
      }

      return SolicitudDocumentoModel.fromMap(row);
    } on StorageException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }
}
