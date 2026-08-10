# Campo Gestor

App de gestão de propriedades rurais voltado para pecuária. Stack: Flutter web-first + Supabase.

See `.planning/PROJECT.md` for vision and `.planning/ROADMAP.md` for phase plan.

## Bootstrap (new clone)

Prerequisites:
- Flutter SDK >= 3.24 (`flutter --version`)
- Docker Desktop (running)
- Supabase CLI: `scoop install supabase` (Windows) or see https://supabase.com/docs/guides/cli/getting-started
- Microsoft Edge (or Chrome) for web target

Setup:
1. `flutter pub get` — install Dart dependencies (after Plan 03 lands)
2. `supabase start` — boot local Postgres + Studio + Auth (after Plan 06 lands)
3. Copy local anon key from `supabase start` output into `.vscode/launch.json` (copy from `.vscode/launch.json.example` first)
4. F5 in VSCode (or `flutter run -d edge --dart-define=...`) to launch the app

## Development

- Tests: `rtk flutter test --no-pub`
- Static analysis: `rtk flutter analyze`
- Custom lint (no Supabase imports in features): `bash scripts/verify_no_supabase_in_features.sh`
- Migrations check: `bash scripts/verify_supabase.sh`

## Deploy

Production web build is hosted on **Cloudflare Pages**: https://campo-gestor.pages.dev/

```bash
dart run tool/deploy.dart            # build web --release + wrangler pages deploy
dart run tool/deploy.dart --dry-run  # print the commands without running them
```

The script reads the `--dart-define` values from the `"Flutter (Web, prod)"` configuration in
`.vscode/launch.json` — the same file F5 uses, so there is no second place for the values to drift.
`.vscode/launch.json` is gitignored; copy `.vscode/launch.json.example` and fill it in on a new clone.

Flags: `--config <name>` (other launch.json configuration), `--project <name>` (other Pages project),
`--dry-run`, `--self-check` (parser tests), `--help`.

- `SUPABASE_ANON_KEY` is a public/publishable key — safe to embed in a client build, never a secret.
  Get it via `get_publishable_keys`, key `"anon"`.
- `APP_ORIGIN` must match the deployed URL — it's used to build auth redirect links (password reset).
- `wrangler` auth: already logged in via OAuth (`npx wrangler whoami` to check). No `wrangler.toml` in the repo — the project name flag is enough for a direct Pages deploy.
- No CI pipeline yet; this is a manual deploy.

## Architecture

Feature-first hybrid (`lib/core/` shared infra + `lib/features/{name}/{data,domain,presentation}`). Repository abstraction means features NEVER import `package:supabase_flutter` directly — only `lib/core/services/` does (per D-06).

Phase 0 status: scaffolding only. Domain features land in Phase 1+.
