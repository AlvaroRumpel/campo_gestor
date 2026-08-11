# Deferred Items — Phase 7

Out-of-scope discoveries logged during plan execution. Not fixed per the
scope-boundary rule (only auto-fix issues directly caused by the current
task's changes).

## From 07-03

- `flutter analyze lib/core/` reports 1 info-level issue,
  `unintended_html_in_doc_comment` at `lib/core/config/app_config.dart:9:41`.
  Pre-existing, in a file untouched by this plan (last touched at
  `0aeeddedd5eec4de304fce6ba8215e60f6a678d9`, before Phase 7). Both files this
  plan created/modified (`lib/core/auth/role_gates.dart`,
  `lib/core/router/routes.dart`) individually pass `flutter analyze` with
  0 issues.
