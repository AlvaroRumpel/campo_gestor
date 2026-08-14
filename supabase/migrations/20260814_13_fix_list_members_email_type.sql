-- 20260814_13_fix_list_members_email_type.sql
-- Correção forward-only descoberta no replay pgTAP do plano 10-11:
-- list_property_members declara RETURNS TABLE (... email text ...) mas
-- auth.users.email é varchar(255); RETURN QUERY em PL/pgSQL é estrito quanto
-- ao tipo (42804: "Returned type character varying(255) does not match
-- expected type text"). Cast explícito u.email::text resolve. Corpo idêntico
-- ao da 20260814_11 fora o cast. CREATE OR REPLACE preserva grants (GRANT a
-- authenticated / REVOKE de anon já aplicados).
CREATE OR REPLACE FUNCTION list_property_members(p_property_id uuid)
RETURNS TABLE (
  user_id    uuid,
  email      text,
  role       role_enum,
  created_at timestamptz,
  is_self    boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT pm.user_id, u.email::text, pm.role, pm.created_at, (pm.user_id = auth.uid())
    FROM property_members pm
    JOIN auth.users u ON u.id = pm.user_id
   WHERE pm.property_id = p_property_id
   ORDER BY pm.created_at;
END;
$$;
