-- =========================================================================
-- MIGRATION 000002: Gestão de Sessões e Trilha de Auditoria (Security)
-- =========================================================================

-- -------------------------------------------------------------------------
-- TABELA: sessions (Gerenciamento de Refresh Tokens e Dispositivos)
-- -------------------------------------------------------------------------
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(512) NOT NULL UNIQUE,
    device_id VARCHAR(255),
    user_agent TEXT,
    ip_address VARCHAR(45),
    is_revoked BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índice obrigatório para buscar rapidamente as sessões ativas de um usuário
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- -------------------------------------------------------------------------
-- TABELA: audit_logs (Trilha de Auditoria e Conformidade)
-- -------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID, -- Nulo se for uma tentativa falha de um usuário não identificado
    
    -- O que aconteceu?
    action VARCHAR(100) NOT NULL, -- Ex: 'login_success', 'update_role', 'delete_upload'
    
    -- Onde aconteceu? (Rastreabilidade do recurso alterado)
    resource_type VARCHAR(100),   -- Ex: 'user', 'mapping', 'tenant_settings'
    resource_id UUID,
    
    -- Como era / Como ficou?
    details JSONB,                -- Guarda o payload da alteração (before/after)
    
    -- Contexto de rede
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices essenciais para renderização rápida do painel de auditoria do cliente
CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- -------------------------------------------------------------------------
-- ROW-LEVEL SECURITY (Isolamento Multi-Tenant para Auditoria)
-- -------------------------------------------------------------------------
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_audit ON audit_logs
    USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- Conceder permissões para o worker da API
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO saas_api_worker;
GRANT SELECT, INSERT ON audit_logs TO saas_api_worker; -- API não pode fazer UPDATE/DELETE em logs de auditoria