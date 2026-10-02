-- -------------------------------------------------------------------------
-- TABELA: notifications (Avisos de processamento e sistema)
-- -------------------------------------------------------------------------
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Se nulo, notifica todos da loja
    type VARCHAR(50) NOT NULL, -- upload_success, billing_alert, system_update
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    action_url VARCHAR(500),
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_tenant_user ON notifications(tenant_id, user_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_notifications ON notifications USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- Permissões
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO saas_api_worker;