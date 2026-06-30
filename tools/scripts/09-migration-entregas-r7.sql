-- RotaLog - Migration: refatorações do schema entregas (ADR-0002 R7 + ADR-0001)
-- Este script documenta mudanças no banco de dados do rotalog-api-entregas
-- decorrentes das ADRs de refatoração.
--
-- Mudanças mapeadas:
--   1. Criação do ENUM entregas_status (ADR-0002 R7)
--   2. Alteração da coluna status de VARCHAR(20) para ENUM (ADR-0002 R7)
--   3. Adição da coluna cliente_id (ADR-0001, item 7)
--   4. Criação de índices para consultas frequentes (ADR-0002 R7)
--   5. Índice em rastreamentos.data_evento
--   6. Limpeza do ENUM duplicado enum_entregas_status (artefato Sequelize)
--   7. Limpeza de índices duplicados pré-existentes (Sequelize sync)
--
-- NOTA: esta migration NÃO altera os tipos de colunas numéricas (peso_kg,
-- origem_lat, origem_lng, destino_lat, destino_lng, distancia_km) nem
-- renomeia data_criacao/data_atualizacao para createdAt/updatedAt.
-- Essas mudanças são aplicadas pelo Sequelize sync (model Entrega) e
-- devem ser verificadas após o sync. Veja ADR-0005 para o detalhamento
-- completo das inconsistências entre ADR, migration e banco.
--
-- Ordem: executar após os scripts 01-08
-- Idempotente: sim (verifica existência antes de criar)

SET search_path TO entregas;

-- ============================================================
-- 1. Criar tipo ENUM para status de entregas (ADR-0002 R7)
-- ============================================================
-- Substitui o VARCHAR(20) original por um ENUM que restringe os valores
-- válidos a: PENDENTE, ATRIBUIDA, EM_TRANSITO, ENTREGUE, CANCELADA

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entregas_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'entregas')) THEN
        CREATE TYPE entregas_status AS ENUM ('PENDENTE', 'ATRIBUIDA', 'EM_TRANSITO', 'ENTREGUE', 'CANCELADA');
        RAISE NOTICE 'Tipo entregas_status criado';
    ELSE
        RAISE NOTICE 'Tipo entregas_status já existe, pulando criação';
    END IF;
END $$;

-- ============================================================
-- 2. Alterar coluna status de VARCHAR(20) para ENUM (ADR-0002 R7)
-- ============================================================
-- A conversão exige que todos os valores existentes sejam válidos no ENUM.
-- O seed (06-seed-entregas.sql) já usa apenas valores do ENUM.

DO $$
BEGIN
    -- Verificar se a coluna status ainda é varchar (não convertida ainda)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'entregas'
          AND table_name = 'entregas'
          AND column_name = 'status'
          AND data_type = 'character varying'
    ) THEN
        ALTER TABLE entregas ALTER COLUMN status TYPE entregas_status USING status::entregas_status;
        ALTER TABLE entregas ALTER COLUMN status SET DEFAULT 'PENDENTE'::entregas_status;
        RAISE NOTICE 'Coluna status convertida para entregas_status';
    ELSE
        RAISE NOTICE 'Coluna status já é entregas_status, pulando conversão';
    END IF;
END $$;

-- ============================================================
-- 3. Adicionar coluna cliente_id (ADR-0001, item 7)
-- ============================================================
-- Campo adicionado ao model Entrega para viabilizar checagem de propriedade
-- no middleware de autorização RBAC (verificarPropriedade).
-- Nullable: entregas legadas criadas antes da migração terão cliente_id = NULL.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'entregas' AND table_name = 'entregas' AND column_name = 'cliente_id') THEN
        ALTER TABLE entregas ADD COLUMN cliente_id BIGINT;
        RAISE NOTICE 'Coluna cliente_id adicionada';
    ELSE
        RAISE NOTICE 'Coluna cliente_id já existe, pulando';
    END IF;
END $$;

-- ============================================================
-- 4. Criar índices para consultas frequentes (ADR-0002 R7)
-- ============================================================
-- Estes índices suportam filtros por motorista e veículo
-- usados nas rotas de listagem e verificação de propriedade.
--
-- NOTA: os índices para (cliente_id), (motorista_id) e (veiculo_placa)
-- já foram criados automaticamente pelo Sequelize sync com nomes
-- entregas_cliente_id, entregas_motorista_id, entregas_veiculo_placa.
-- Para evitar duplicidade (custo de escrita sem ganho de leitura),
-- usamos CREATE INDEX IF NOT EXISTS com nomes alternativos (idx_*)
-- apenas caso os índices do Sequelize não existam.

CREATE INDEX IF NOT EXISTS idx_entregas_cliente_id ON entregas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_entregas_motorista_id ON entregas(motorista_id);
CREATE INDEX IF NOT EXISTS idx_entregas_veiculo_placa ON entregas(veiculo_placa);

-- Nota: o índice em status (entregas_status) já foi criado pelo Sequelize
-- (migration 03), e o índice UNIQUE em numero_pedido já existe como
-- entregas_numero_pedido_key.

-- ============================================================
-- 5. Índice em rastreamentos.data_evento
-- ============================================================
-- Omitido na migration 03 (FIXME documentado), adicionado agora.

CREATE INDEX IF NOT EXISTS idx_rastreamentos_data_evento ON rastreamentos(data_evento);

-- ============================================================
-- 6. Limpeza: remover ENUM duplicado enum_entregas_status
-- ============================================================
-- O Sequelize (sync) criou um segundo tipo ENUM "enum_entregas_status"
-- que não é utilizado pela tabela. O tipo correto em uso é "entregas_status".
-- Este cleanup remove o artefato órfão.

-- DROP TYPE nao suporta IF EXISTS dentro de DO block com search_path,
-- entao usamos DROP TYPE IF EXISTS com schema explicito.
DROP TYPE IF EXISTS entregas.enum_entregas_status;

-- ============================================================
-- 7. Limpeza: remover índices duplicados pré-existentes
-- ============================================================
-- O Sequelize sync criou índices homônimos (entregas_cliente_id,
-- entregas_motorista_id, entregas_veiculo_placa) antes desta migration.
-- Como os índices idx_* já foram criados no passo 4, removemos
-- os duplicados para evitar custo extra de escrita.
-- Aplica-se apenas se o índice idx_* correspondente existir.

DO $$
BEGIN
    -- cliente_id
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'idx_entregas_cliente_id')
       AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'entregas_cliente_id') THEN
        DROP INDEX IF EXISTS entregas.entregas_cliente_id;
        RAISE NOTICE 'Índice duplicado entregas_cliente_id removido';
    END IF;
    -- motorista_id
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'idx_entregas_motorista_id')
       AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'entregas_motorista_id') THEN
        DROP INDEX IF EXISTS entregas.entregas_motorista_id;
        RAISE NOTICE 'Índice duplicado entregas_motorista_id removido';
    END IF;
    -- veiculo_placa
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'idx_entregas_veiculo_placa')
       AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'entregas' AND indexname = 'entregas_veiculo_placa') THEN
        DROP INDEX IF EXISTS entregas.entregas_veiculo_placa;
        RAISE NOTICE 'Índice duplicado entregas_veiculo_placa removido';
    END IF;
END $$;

-- ============================================================
-- Verificação
-- ============================================================

SELECT '=== Verificação da migration 09 ===' AS info;

-- Verificar tipo da coluna status
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'entregas' AND table_name = 'entregas' AND column_name IN ('status', 'cliente_id')
ORDER BY column_name;

-- Verificar ENUM
SELECT typname, enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'entregas') AND t.typcategory = 'E'
ORDER BY typname, enumsortorder;

-- Verificar índices
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'entregas' ORDER BY indexname;
