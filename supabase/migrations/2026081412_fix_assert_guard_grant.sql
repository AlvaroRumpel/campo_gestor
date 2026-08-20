-- 20260814_12_fix_assert_guard_grant.sql
-- Correção forward-only do ponto 11 da verificação de catálogo do plano 10-11:
-- assert_not_last_veterinarian() ficou executável por `authenticated` porque o
-- ALTER DEFAULT PRIVILEGES do Supabase concede EXECUTE em toda função nova e a
-- 20260814_11 só revogou de `public`. A função é interna (chamada apenas de
-- dentro dos RPCs SECURITY DEFINER remove_member / update_member_role /
-- leave_property) — nenhum client deve poder invocá-la.
REVOKE EXECUTE ON FUNCTION assert_not_last_veterinarian(uuid, uuid)
  FROM authenticated, anon, PUBLIC;
