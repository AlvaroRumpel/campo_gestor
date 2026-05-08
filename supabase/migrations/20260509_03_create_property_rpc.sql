-- 20260508_03_create_property_rpc.sql
-- Atomic RPC for property creation — avoids RLS race where SELECT-after-INSERT
-- fails because membership does not exist yet at RETURNING evaluation time.
-- References: T-02-12, D-04

CREATE OR REPLACE FUNCTION create_property_with_membership(
  p_name  text,
  p_owner text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_id  uuid;
  v_row json;
BEGIN
  INSERT INTO properties (name, owner)
  VALUES (p_name, p_owner)
  RETURNING id INTO v_id;

  INSERT INTO property_members (user_id, property_id, role)
  VALUES (auth.uid(), v_id, 'veterinarian');

  SELECT row_to_json(p) INTO v_row
  FROM (
    SELECT id, name, owner, created_at, deleted_at
    FROM properties
    WHERE id = v_id
  ) p;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION create_property_with_membership(text, text) FROM public;
GRANT EXECUTE ON FUNCTION create_property_with_membership(text, text) TO authenticated;
