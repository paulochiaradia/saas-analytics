-- =========================================================================
-- MIGRATION 000007: Fábrica de Schemas Dinâmicos (Core Domain)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.create_tenant_schema()
RETURNS TRIGGER AS $$
DECLARE
    -- Formata o nome do schema usando o UUID do tenant (ex: tenant_123e4567_e89b...)
    v_schema VARCHAR := 'tenant_' || REPLACE(NEW.id::text, '-', '_');
BEGIN
    -- Cria o schema isolado do cliente
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', v_schema);

    -- ── 1. Tabela de Clientes ────────────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.clientes (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            cliente_key VARCHAR(100) NOT NULL UNIQUE, -- ID no ERP
            nome VARCHAR(255) NOT NULL,
            email VARCHAR(255),
            tipo VARCHAR(50) DEFAULT ''pessoa_fisica'',
            documento VARCHAR(20),
            telefone VARCHAR(20),
            cidade VARCHAR(100),
            uf VARCHAR(2),
            bairro VARCHAR(100),
            cep VARCHAR(10),
            ativo BOOLEAN NOT NULL DEFAULT true,
            atributos JSONB NOT NULL DEFAULT ''{}'',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema);

    -- ── 2. Tabela de Fornecedores ────────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.fornecedores (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            fornecedor_key VARCHAR(100) NOT NULL UNIQUE,
            nome VARCHAR(255) NOT NULL,
            email VARCHAR(255),
            documento VARCHAR(20),
            telefone VARCHAR(20),
            cidade VARCHAR(100),
            uf VARCHAR(2),
            ativo BOOLEAN NOT NULL DEFAULT true,
            atributos JSONB NOT NULL DEFAULT ''{}'',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema);

    -- ── 3. Tabela de Produtos ────────────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.produtos (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            produto_key VARCHAR(100) NOT NULL UNIQUE, -- ID no ERP
            sku VARCHAR(100),
            codigo_barras VARCHAR(50), -- EAN/UPC
            nome VARCHAR(255) NOT NULL,
            marca VARCHAR(100),
            categoria VARCHAR(100),
            subcategoria VARCHAR(100),
            unidade VARCHAR(20) DEFAULT ''UN'',
            preco_custo NUMERIC(12,2) DEFAULT 0,
            preco_venda NUMERIC(12,2) DEFAULT 0,
            ativo BOOLEAN NOT NULL DEFAULT true,
            atributos JSONB NOT NULL DEFAULT ''{}'',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema);

    -- ── 4. Tabela de Vendas ──────────────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.vendas (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            venda_key VARCHAR(100) NOT NULL UNIQUE,
            data_venda TIMESTAMP WITH TIME ZONE NOT NULL,
            cliente_id UUID REFERENCES %I.clientes(id) ON DELETE SET NULL,
            cliente_key VARCHAR(100), -- Mantemos o ID do ERP caso o cliente ainda não esteja syncado
            vendedor_id VARCHAR(100),
            forma_pagamento VARCHAR(50),
            total NUMERIC(12,2) NOT NULL DEFAULT 0,
            custo_total NUMERIC(12,2) NOT NULL DEFAULT 0, -- Essencial para DRE
            desconto NUMERIC(12,2) NOT NULL DEFAULT 0,
            impostos NUMERIC(12,2) NOT NULL DEFAULT 0,
            status VARCHAR(50) NOT NULL DEFAULT ''concluida'',
            canal VARCHAR(50) DEFAULT ''balcao'',
            atributos JSONB NOT NULL DEFAULT ''{}'',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema, v_schema);

    -- Índices Analíticos (Dashboards)
    EXECUTE format('CREATE INDEX idx_%I_vendas_data ON %I.vendas(data_venda DESC)', v_schema, v_schema);
    EXECUTE format('CREATE INDEX idx_%I_vendas_status ON %I.vendas(status)', v_schema, v_schema);

    -- ── 5. Tabela de Itens de Venda ──────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.itens_venda (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            venda_id UUID NOT NULL REFERENCES %I.vendas(id) ON DELETE CASCADE,
            produto_id UUID REFERENCES %I.produtos(id) ON DELETE SET NULL,
            produto_key VARCHAR(100) NOT NULL,
            descricao VARCHAR(255) NOT NULL,
            quantidade NUMERIC(12,3) NOT NULL,
            unidade VARCHAR(20) DEFAULT ''UN'',
            custo_unitario NUMERIC(12,2) NOT NULL DEFAULT 0, -- Essencial para margem do item
            preco_unitario NUMERIC(12,2) NOT NULL,
            desconto NUMERIC(12,2) NOT NULL DEFAULT 0,
            total NUMERIC(12,2) NOT NULL,
            atributos JSONB NOT NULL DEFAULT ''{}''
        )', v_schema, v_schema, v_schema);

    -- ── 6. Tabela de Estoque ─────────────────────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.estoque (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            produto_id UUID REFERENCES %I.produtos(id) ON DELETE CASCADE,
            produto_key VARCHAR(100) NOT NULL UNIQUE,
            quantidade NUMERIC(12,3) NOT NULL DEFAULT 0,
            quantidade_min NUMERIC(12,3) NOT NULL DEFAULT 0,
            quantidade_max NUMERIC(12,3),
            custo_medio NUMERIC(12,2) DEFAULT 0, -- Valorização do estoque
            localizacao VARCHAR(100),
            atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema, v_schema);

    -- ── 7. Tabela de Movimentos de Estoque ───────────────────
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.movimentos_estoque (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            produto_id UUID REFERENCES %I.produtos(id) ON DELETE SET NULL,
            produto_key VARCHAR(100) NOT NULL,
            tipo VARCHAR(50) NOT NULL, -- entrada, saida, ajuste
            quantidade NUMERIC(12,3) NOT NULL,
            custo_movimento NUMERIC(12,2) DEFAULT 0,
            motivo VARCHAR(100),
            referencia VARCHAR(100), -- ID da venda ou compra que gerou o movimento
            atributos JSONB NOT NULL DEFAULT ''{}'',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', v_schema, v_schema);

    EXECUTE format('CREATE INDEX idx_%I_movimentos_data ON %I.movimentos_estoque(created_at DESC)', v_schema, v_schema);

    -- ── Permissões de Acesso ─────────────────────────────────
    -- Garante que o usuário da API (Go) e do Worker (Python) possam manipular as tabelas
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO saas_api_worker', v_schema);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO saas_api_worker', v_schema);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL PRIVILEGES ON TABLES TO saas_api_worker', v_schema);

    RAISE NOTICE 'Schema % criado e configurado com sucesso.', v_schema;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── O Gatilho de Automação ───────────────────────────────
CREATE TRIGGER trigger_create_tenant_schema
    AFTER INSERT ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.create_tenant_schema();