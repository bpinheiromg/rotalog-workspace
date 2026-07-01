-- RotaLog - API Frotas - Tabela de Alertas de Manutenção Preventiva
-- Documentação da feature "Alerta de Manutenção Preventiva" (DoD.md).
-- Armazena registro de alertas gerados quando um veículo atinge o limite de
-- quilometragem ou fica X meses sem manutenção.
--
-- Mudanças mapeadas:
--   1. Criação da tabela alertas_manutencao (schema frotas)
--   2. Índices para consultas por veículo, status e data do alerta
--
-- Observação: existe migration de alertas_manutencao também cadastrada no
-- Flyway do projeto (V3__alertas_manutencao.sql), mas o Flyway está
-- desabilitado em application.properties (spring.flyway.enabled=false).
-- A criação real do schema é feita via docker-compose (initdb scripts).
-- Mantemos este script para garantir que o ambiente de desenvolvimento
-- provisione a tabela mesmo com Flyway desabilitado.
--
-- Ordem: executar após os scripts 01-09
-- Idempotente: sim (CREATE TABLE IF NOT EXISTS + IF NOT EXISTS em índices)

SET search_path TO frotas;

-- ============================================================
-- Tabela de alertas de manutenção preventiva
-- ============================================================
CREATE TABLE IF NOT EXISTS alertas_manutencao (
    id BIGSERIAL PRIMARY KEY,
    veiculo_id BIGINT NOT NULL,
    tipo_alerta VARCHAR(20) NOT NULL,          -- 'QUILOMETRAGEM' ou 'TEMPO'
    quilometragem_atual BIGINT,                -- km no momento do alerta
    limite_quilometragem BIGINT,               -- limite configurado (ex.: 50000)
    intervalo_meses INTEGER,                   -- intervalo configurado (ex.: 3)
    data_ultima_manutencao TIMESTAMP,          -- data da última manutenção concluída
    status_notificacao VARCHAR(20) NOT NULL DEFAULT 'PENDENTE', -- 'ENVIADA' | 'PENDENTE' | 'FALHA'
    notificacao_id BIGINT,                     -- id retornado pela api-notificacoes (NULL se falha)
    data_alerta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_resolucao TIMESTAMP,                  -- preenchido quando o alerta é resolvido (manutenção executada)
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- TODO: Adicionar FK para veiculos(id) quando o legado de foreign keys for refatorado
-- TODO: Adicionar CHECK constraint para tipo_alerta e status_notificacao
-- FIXME: Colunas VARCHAR para enums - deveriam ser tipo enumerado ou lookup table

-- ============================================================
-- Índices para consultas frequentes
-- ============================================================
-- Consulta por veículo (usado para evitar alertas duplicados pendentes)
CREATE INDEX IF NOT EXISTS idx_alertas_veiculo_id ON alertas_manutencao(veiculo_id);

-- Consulta por status (usado no painel-admin e no reprocessamento de pendentes)
CREATE INDEX IF NOT EXISTS idx_alertas_status_notificacao ON alertas_manutencao(status_notificacao);

-- Consulta por data (usado para listagem ordenada e filtros temporais)
CREATE INDEX IF NOT EXISTS idx_alertas_data_alerta ON alertas_manutencao(data_alerta);

-- Índice composto veículo+status (otimiza a checagem de alerta pendente duplicado)
CREATE INDEX IF NOT EXISTS idx_alertas_veiculo_status ON alertas_manutencao(veiculo_id, status_notificacao);

-- FIXME: Sem particionamento por data (para quando a tabela crescer)
-- FIXME: Sem estratégia de arquivamento de alertas resolvidos antigos

-- ============================================================
-- Verificação
-- ============================================================
SELECT '=== Verificação da migration 10: alertas_manutencao ===' AS info;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'frotas' AND table_name = 'alertas_manutencao'
ORDER BY ordinal_position;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'frotas' AND tablename = 'alertas_manutencao'
ORDER BY indexname;
