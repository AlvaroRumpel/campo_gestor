import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env/env.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pitfall 7: must run BEFORE runApp to avoid hash routing on web.
  usePathUrlStrategy();

  // D-08: secrets enter via dart-define. Fails fast with a helpful message
  // when the developer forgot --dart-define flags or .vscode/launch.json.
  Env.requireOrThrow();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  runApp(
    const ProviderScope(retry: providerRetryPolicy, child: CampoGestorApp()),
  );
}

/// App-wide retry policy for every Riverpod provider (G-06-9).
///
/// PostgREST answers with a [PostgrestException] for anything the server
/// understood and deliberately refused — a malformed filter, a policy
/// denial, a constraint violation — which is the non-transient class:
/// retrying it just re-issues the identical failure roughly ten times
/// behind a spinner instead of letting the provider settle into its error
/// state. A genuinely transient failure (a socket or client exception)
/// still gets [ProviderContainer.defaultRetry]'s backoff.
///
/// Ceiling: a Postgres statement timeout also surfaces as a
/// [PostgrestException] and is misclassified here as non-transient.
/// Accepted for now — upgrade path is to branch on the exception's `code`.
Duration? providerRetryPolicy(int retryCount, Object error) {
  if (error is PostgrestException) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

class CampoGestorApp extends ConsumerWidget {
  const CampoGestorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Campo Gestor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // D-13 + Pitfall 8: pt-BR locale with full Material delegates.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}
