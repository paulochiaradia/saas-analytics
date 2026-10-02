-- -------------------------------------------------------------------------
-- TABELA: tenant_settings (Preferências Visuais e Operacionais)
-- -------------------------------------------------------------------------
CREATE TABLE tenant_settings (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    theme VARCHAR(20) DEFAULT 'light',
    language VARCHAR(10) DEFAULT 'pt-BR',
    report_email_frequency VARCHAR(20) DEFAULT 'weekly', -- daily, weekly, monthly, none
    custom_domain VARCHAR(255) UNIQUE, -- Para White-label (ex: painel.minhafarmacia.com.br)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_tenant_settings_updated_at BEFORE UPDATE ON tenant_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Inserir configuração padrão automaticamente quando um tenant for criado
CREATE OR REPLACE FUNCTION create_default_tenant_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO tenant_settings (tenant_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_tenant_settings
    AFTER INSERT ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION create_default_tenant_settings();

-- RLS
ALTER TABLE tenant_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_tenant_settings ON tenant_settings USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- Permissões
GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_settings TO saas_api_worker;