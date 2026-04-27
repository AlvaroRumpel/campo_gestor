#!/usr/bin/env bash
# SC-5: features/ must NEVER import package:supabase_flutter directly.
# Repository pattern (D-06) requires going through lib/core/services/.
set -euo pipefail

if [ ! -d "lib/features" ]; then
  echo "lib/features/ does not exist yet — script is a no-op."
  exit 0
fi

OFFENDERS=$(grep -r --include="*.dart" "package:supabase_flutter" lib/features/ 2>/dev/null || true)

if [ -n "$OFFENDERS" ]; then
  echo "FAIL: Direct supabase_flutter imports in features/ violate D-06 (Abstract Repository pattern):"
  echo "$OFFENDERS"
  exit 1
fi

echo "OK: No direct supabase_flutter imports in lib/features/."
exit 0
