import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// keepAlive: SupabaseService is process-singleton; never disposed.
final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(),
);
