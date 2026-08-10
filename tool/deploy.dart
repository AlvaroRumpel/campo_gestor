// Build + deploy do web app para Cloudflare Pages.
//
// As variáveis vêm de .vscode/launch.json (gitignored) — mesma fonte usada
// pelo F5 do VSCode, então não existe um segundo lugar para desincronizar.
// Use .vscode/launch.json.example como template.
//
//   dart run tool/deploy.dart
//   dart run tool/deploy.dart --config "Flutter (Edge, cloud)" --dry-run
//   dart run tool/deploy.dart --project outro-projeto
//   dart run tool/deploy.dart --self-check

import 'dart:convert';
import 'dart:io';

const _defaultConfig = 'Flutter (Web, prod)';
const _defaultProject = 'campo-gestor';
const _buildDir = 'build/web';

Future<void> main(List<String> argv) async {
  if (argv.contains('--help') || argv.contains('-h')) {
    stdout.write(_usage);
    return;
  }
  if (argv.contains('--self-check')) {
    _selfCheck();
    return;
  }

  final configName = _flag(argv, '--config') ?? _defaultConfig;
  final project = _flag(argv, '--project') ?? _defaultProject;
  final dryRun = argv.contains('--dry-run');

  // Roda a partir da raiz do repo, independente do cwd de quem chamou.
  final repoRoot = File.fromUri(Platform.script).parent.parent;
  Directory.current = repoRoot;

  final launchFile = File('.vscode/launch.json');
  if (!launchFile.existsSync()) {
    _die('.vscode/launch.json não encontrado. '
        'Copie de .vscode/launch.json.example e preencha os valores.');
  }

  final List<String> defines;
  try {
    defines = dartDefinesFor(launchFile.readAsStringSync(), configName);
  } on FormatException catch (e) {
    _die('.vscode/launch.json não é JSON válido (vírgula sobrando?): $e');
  } on ArgumentError catch (e) {
    _die(e.message.toString());
  }

  if (defines.isEmpty) {
    _die('Config "$configName" não tem nenhum --dart-define.');
  }

  stdout.writeln('config:  $configName');
  stdout.writeln('project: $project');
  stdout.writeln('defines: ${defines.map(_mask).join('\n         ')}');
  stdout.writeln('');

  await _run('flutter', ['build', 'web', '--release', ...defines],
      dryRun: dryRun);
  await _run(
    'npx',
    ['wrangler', 'pages', 'deploy', _buildDir, '--project-name=$project'],
    dryRun: dryRun,
  );

  stdout.writeln(dryRun ? '\ndry-run: nada executado.' : '\ndeploy ok.');
}

/// Extrai os args `--dart-define=...` da configuração [configName] de um
/// launch.json (JSONC — comentários permitidos).
List<String> dartDefinesFor(String jsonc, String configName) {
  final root = jsonDecode(stripJsonComments(jsonc));
  if (root is! Map || root['configurations'] is! List) {
    throw ArgumentError('launch.json sem lista "configurations".');
  }
  for (final cfg in root['configurations'] as List) {
    if (cfg is! Map || cfg['name'] != configName) continue;
    final args = cfg['args'];
    if (args is! List) return const [];
    return args
        .whereType<String>()
        .where((a) => a.startsWith('--dart-define='))
        .toList();
  }
  final names = (root['configurations'] as List)
      .whereType<Map>()
      .map((c) => c['name'])
      .join(', ');
  throw ArgumentError('Config "$configName" não existe. Disponíveis: $names');
}

/// Remove comentários `//` e `/* */` respeitando strings — `http://` em um
/// valor não pode virar comentário.
String stripJsonComments(String src) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  while (i < src.length) {
    final c = src[i];
    if (inString) {
      out.write(c);
      if (c == r'\' && i + 1 < src.length) {
        out.write(src[i + 1]);
        i += 2;
        continue;
      }
      if (c == '"') inString = false;
      i++;
      continue;
    }
    if (c == '"') {
      inString = true;
      out.write(c);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < src.length) {
      if (src[i + 1] == '/') {
        while (i < src.length && src[i] != '\n') {
          i++;
        }
        continue;
      }
      if (src[i + 1] == '*') {
        i += 2;
        while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

String? _flag(List<String> argv, String name) {
  final i = argv.indexOf(name);
  if (i >= 0 && i + 1 < argv.length) return argv[i + 1];
  final inline = argv.firstWhere((a) => a.startsWith('$name='),
      orElse: () => '');
  return inline.isEmpty ? null : inline.substring(name.length + 1);
}

/// Anon key é publishable, mas não há motivo pra despejar no log.
String _mask(String define) {
  if (!define.contains('KEY=')) return define;
  final head = define.substring(0, define.indexOf('KEY=') + 4);
  final value = define.substring(head.length);
  return '$head${value.length <= 8 ? '***' : '${value.substring(0, 8)}…'}';
}

Future<void> _run(
  String exe,
  List<String> args, {
  required bool dryRun,
}) async {
  stdout.writeln('\$ $exe ${args.map(_mask).join(' ')}');
  if (dryRun) return;
  final proc = await Process.start(
    exe,
    args,
    runInShell: true, // Windows: resolve flutter.bat / npx.cmd
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await proc.exitCode;
  if (code != 0) _die('$exe falhou (exit $code)', code);
}

Never _die(String message, [int code = 1]) {
  stderr.writeln('erro: $message');
  exit(code);
}

const _usage = '''
Uso: dart run tool/deploy.dart [opções]

  --config <nome>    Configuração do .vscode/launch.json (padrão: "$_defaultConfig")
  --project <nome>   Projeto do Cloudflare Pages (padrão: $_defaultProject)
  --dry-run          Imprime os comandos sem executar
  --self-check       Roda os testes do parser
  -h, --help         Esta ajuda
''';

void _selfCheck() {
  const sample = '''
{
  // comentário com "aspas e http://nao-e-comentario
  "configurations": [
    {
      "name": "A",
      "args": [
        "--dart-define=SUPABASE_URL=http://127.0.0.1:54321",
        "--web-port=3000"
      ]
    },
    /* bloco
       multilinha */
    { "name": "B", "args": ["--dart-define=SUPABASE_ANON_KEY=abcdefghij"] },
    { "name": "C" }
  ]
}
''';

  void check(bool ok, String what) {
    if (!ok) _die('self-check falhou: $what');
  }

  check(
    dartDefinesFor(sample, 'A').single ==
        '--dart-define=SUPABASE_URL=http://127.0.0.1:54321',
    'URL com // dentro de string virou comentário, ou --web-port vazou',
  );
  check(dartDefinesFor(sample, 'B').length == 1, 'bloco /* */ não removido');
  check(dartDefinesFor(sample, 'C').isEmpty, 'config sem args deve dar vazio');

  var threw = false;
  try {
    dartDefinesFor(sample, 'inexistente');
  } on ArgumentError {
    threw = true;
  }
  check(threw, 'config inexistente deveria lançar');

  check(
    _mask('--dart-define=SUPABASE_ANON_KEY=sb_publishable_secreto') ==
        '--dart-define=SUPABASE_ANON_KEY=sb_publi…',
    'mask não truncou a key',
  );
  check(
    _flag(['--config', 'X'], '--config') == 'X' &&
        _flag(['--config=Y'], '--config') == 'Y' &&
        _flag([], '--config') == null,
    '_flag não parseia as duas formas',
  );

  stdout.writeln('self-check ok');
}
