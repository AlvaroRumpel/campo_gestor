// Repositório das RPCs bulk (migration 20260820_15). Widgets nunca importam
// supabase_flutter — o PostgrestException é traduzido aqui para
// BulkImportException com a mensagem "linha N: motivo" vinda do servidor.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';

class BulkImportException implements Exception {
  const BulkImportException(this.message);
  final String message;

  @override
  String toString() => 'BulkImportException: $message';
}

class BulkRepository {
  BulkRepository(this._service);
  final SupabaseService _service;

  Future<Map<String, dynamic>> _rpc(String fn, String propertyId,
      List<Map<String, dynamic>> rows) async {
    try {
      final r = await _service.client.rpc(
        fn,
        params: {'p_property_id': propertyId, 'p_rows': rows},
      );
      return r as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw BulkImportException(e.message);
    }
  }

  Future<({int created, int updated})> upsertAnimals(
      String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _rpc('bulk_upsert_animals', propertyId, rows);
    return (created: r['created'] as int, updated: r['updated'] as int);
  }

  Future<({int created, int updated})> upsertDoses(
      String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _rpc('bulk_upsert_doses', propertyId, rows);
    return (created: r['created'] as int, updated: r['updated'] as int);
  }

  Future<({int applications, int animals})> registerSanitary(
      String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _rpc('bulk_register_sanitary', propertyId, rows);
    return (
      applications: r['applications'] as int,
      animals: r['animals'] as int,
    );
  }
}

final bulkRepositoryProvider = Provider<BulkRepository>(
  (ref) => BulkRepository(ref.watch(supabaseServiceProvider)),
);
