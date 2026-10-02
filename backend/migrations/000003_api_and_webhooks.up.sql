-- -------------------------------------------------------------------------
-- TABELA: api_keys (Chaves de Integração de ERPs)
-- -------------------------------------------------------------------------
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    prefix VARCHAR(20) NOT NULL, -- Ex: saas_8f2a (para identificação visual)
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------------------
-- TABELA: webhook_endpoints (Rotas cadastradas pelo cliente)
-- -------------------------------------------------------------------------
CREATE TABLE webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    target_url VARCHAR(500) NOT NULL,
    secret VARCHAR(255) NOT NULL, -- Para assinar o payload enviado ao cliente
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Triggers de Updated At
CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON api_keys FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_webhook_endpoints_updated_at BEFORE UPDATE ON webhook_endpoints FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_endpoints ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_api_keys ON api_keys USING (tenant_id = current_setting('app.current_tenant', true)::UUID);
CREATE POLICY tenant_isolation_webhook_endpoints ON webhook_endpoints USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- Permissões
GRANT SELECT, INSERT, UPDATE, DELETE ON api_keys, webhook_endpoints TO saas_api_worker;