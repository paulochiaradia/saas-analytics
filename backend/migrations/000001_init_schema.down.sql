-- =========================================================================
-- ROLLBACK MIGRATION 000001
-- =========================================================================

-- Revogar permissões e remover o usuário da aplicação
DROP OWNED BY saas_api_worker;
DROP ROLE IF EXISTS saas_api_worker;

-- Remover tabelas (o CASCADE já cuida das políticas de RLS atreladas a elas)
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

-- Remover a função de trigger
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;