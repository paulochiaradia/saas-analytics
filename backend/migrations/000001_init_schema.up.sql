-- =========================================================================
-- MIGRATION 000001: Domínio de Identidade e Acesso (IAM)
-- =========================================================================

-- Habilita a extensão para geração nativa de UUIDs caso não exista
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------------------------
-- TABELA: tenants (Empresas/Lojistas)
-- -------------------------------------------------------------------------
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identificação Corporativa
    corporate_name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    document VARCHAR(20) UNIQUE NOT NULL, -- CNPJ
    segment VARCHAR(50) NOT NULL,
    timezone VARCHAR(50) DEFAULT 'America/Sao_Paulo',
    
    -- Assinaturas e Limites (Billing & Tiers)
    tier VARCHAR(50) DEFAULT 'bronze', -- bronze, silver, gold, enterprise
    billing_cycle VARCHAR(50) DEFAULT 'monthly',
    max_users INTEGER DEFAULT 5,
    max_storage_mb INTEGER DEFAULT 1024,
    
    -- Motor de Ingestão e Integração
    allow_manual_upload BOOLEAN DEFAULT true,
    allow_api BOOLEAN DEFAULT false,
    allow_webhook BOOLEAN DEFAULT false,
    webhook_secret VARCHAR(255),
    
    -- Ciclo de Vida e Auditoria
    status VARCHAR(50) DEFAULT 'onboarding', -- onboarding, active, suspended, canceled
    created_by UUID, -- Preenchido posteriormente se criado por um admin interno
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- -------------------------------------------------------------------------
-- TABELA: users (Acessos ao Painel)
-- -------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Identidade e Perfil
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    role VARCHAR(50) NOT NULL DEFAULT 'viewer', -- manager, stock_clerk, buyer
    
    -- Segurança Ativa e Controle de Acesso
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(255),
    last_login_at TIMESTAMP WITH TIME ZONE,
    last_login_ip VARCHAR(50),
    
    -- Recuperação de Senha
    reset_password_token VARCHAR(255),
    reset_password_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Ciclo de Vida e Auditoria
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- -------------------------------------------------------------------------
-- FUNÇÕES E TRIGGERS (Auto-atualização do updated_at)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- -------------------------------------------------------------------------
-- ROW-LEVEL SECURITY (Isolamento Multi-Tenant)
-- -------------------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_users ON users
    USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- -------------------------------------------------------------------------
-- USUÁRIO DA APLICAÇÃO (Least Privilege)
-- -------------------------------------------------------------------------
-- (O IF NOT EXISTS não funciona diretamente no CREATE ROLE, usamos um bloco DO)
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'saas_api_worker') THEN
      CREATE ROLE saas_api_worker LOGIN PASSWORD 'm2V_b8N!x5Cq@Z1l';
   END IF;
END
$do$;

GRANT CONNECT ON DATABASE saas_db TO saas_api_worker;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO saas_api_worker;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO saas_api_worker;