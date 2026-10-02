DROP TRIGGER IF EXISTS trigger_create_tenant_settings ON tenants;
DROP FUNCTION IF EXISTS create_default_tenant_settings();
DROP TABLE IF EXISTS tenant_settings CASCADE;