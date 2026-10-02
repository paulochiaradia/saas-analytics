-- =========================================================================
-- ROLLBACK MIGRATION 000007
-- =========================================================================

DROP TRIGGER IF EXISTS trigger_create_tenant_schema ON public.tenants;
DROP FUNCTION IF EXISTS public.create_tenant_schema();

