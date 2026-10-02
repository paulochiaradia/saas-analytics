-- =========================================================================
-- ROLLBACK MIGRATION 000002
-- =========================================================================

-- Revogar permissões específicas concedidas nesta migration
REVOKE ALL PRIVILEGES ON audit_logs FROM saas_api_worker;
REVOKE ALL PRIVILEGES ON sessions FROM saas_api_worker;

-- Remover tabelas (Cascades e RLS caem junto)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;