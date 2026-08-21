-- 20260824_19_revoke_anon_rpcs.sql — fecha o débito do audit v1.0: `anon`
-- tinha EXECUTE em 12 RPCs SECURITY DEFINER (módulo IATF + bulk_*). As
-- guardas falham fechado, mas a diferença de SQLSTATE (42501 vs 23503)
-- forma um oráculo de existência de UUID para não-autenticados.
--
-- Duas partes: (1) varredura das 12 existentes; (2) default privileges —
-- funções novas criadas por `postgres` no schema public deixam de ganhar
-- EXECUTE automático para anon (raiz do problema: o default do Supabase
-- concede a anon/authenticated/service_role na criação).

REVOKE EXECUTE ON FUNCTION add_animals_to_iatf(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION assert_vet_of(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_register_sanitary(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_upsert_animals(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_upsert_doses(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_upsert_expenses(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_upsert_lots(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION bulk_upsert_paddocks(uuid, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION close_iatf(uuid) FROM anon;
-- Trigger function: o EXECUTE de anon vinha de um GRANT a PUBLIC na criação
-- (inerte via API — PostgREST não expõe funções que retornam trigger — mas
-- fechado por higiene).
REVOKE ALL ON FUNCTION deactivate_iatf_membership_on_baixa() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION remove_animal_from_iatf(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION save_dg_records(uuid, jsonb) FROM anon;

-- Funções futuras: sem grant automático para anon.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;
