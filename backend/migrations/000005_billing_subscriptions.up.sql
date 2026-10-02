-- -------------------------------------------------------------------------
-- TABELA: subscriptions (Espelho do Gateway de Pagamento, ex: Stripe)
-- -------------------------------------------------------------------------
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL UNIQUE REFERENCES tenants(id) ON DELETE CASCADE,
    gateway_customer_id VARCHAR(100), -- ID do cliente no Stripe/Iugu
    gateway_subscription_id VARCHAR(100), -- ID da assinatura no Stripe/Iugu
    plan_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'trialing', -- trialing, active, past_due, canceled
    current_period_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_subscriptions ON subscriptions USING (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- Permissões
GRANT SELECT, INSERT, UPDATE, DELETE ON subscriptions TO saas_api_worker;