import 'package:supabase_flutter/supabase_flutter.dart';

/// Single point of Supabase SDK access in the app.
///
/// Per D-06 (CONTEXT.md, Abstract Repository pattern), features NEVER import
/// `package:supabase_flutter` directly. Concrete repositories in `data/` of
/// each feature accept a [SupabaseService] (via Riverpod) and route all
/// Postgres/auth calls through it.
class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;
}
