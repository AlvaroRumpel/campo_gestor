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

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: CampoGestorApp()));
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
