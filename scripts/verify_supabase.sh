#!/usr/bin/env bash
# SC-2: Verify migrations apply cleanly against local Supabase.
# Requires: Docker Desktop running + Supabase CLI installed + `supabase start` already executed.
set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "FAIL: supabase CLI not found in PATH. Install via 'scoop install supabase'."
  exit 2
fi

if ! docker info >/dev/null 2>&1; then
  echo "FAIL: Docker daemon not reachable. Start Docker Desktop first."
  exit 3
fi

echo "Running 'supabase db reset' (applies all migrations from a clean state)..."
supabase db reset
echo "OK: supabase db reset completed without error."
exit 0
