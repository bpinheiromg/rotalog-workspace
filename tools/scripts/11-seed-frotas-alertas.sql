-- RotaLog - API Frotas - Seed de Alertas de Manutenção Preventiva
-- Popula a tabela alertas_manutencao com os veículos do seed-frotas.sql
-- que estão atualmente elegíveis à manutenção preventiva.
--
-- Critério de elegibilidade (>= veiculo.quilometragem.limite-manutencao,
-- configurado em 50000 km no application.properties) E status = 'ATIVO':
--
--  placa     | modelo              | km      | status     | elegível?
-- -----------|---------------------|---------|------------|----------
--  ABC1D23   | Fiat Fiorino        |  45.000 | ATIVO      | não (abaixo 50k)
--  DEF4G56   | VW Delivery 9.170   | 120.000 | ATIVO      | SIM
--  GHI7J89   | Mercedes Sprinter   |  32.000 | ATIVO      | não
--  JKL0M12   | Iveco Daily         | 180.000 | MANUTENCAO | não (não ATIVO)
--  NOP3Q45   | Renault Master      |  15.000 | ATIVO      | não
--  RST6U78   | Fiat Ducato         | 210.000 | INATIVO    | não (não ATIVO)
--  VWX9Y01   | VW Constellation    |  95.000 | ATIVO      | SIM
--  BCD2E34   | Scania R450         |  78.000 | ATIVO      | SIM
--  FGH5I67   | Volvo FH 540        | 150.000 | ATIVO      | SIM
--  JKL8M90   | Mercedes Actros     |  42.000 | ATIVO      | não
--
-- Resultado: 4 veículos elegíveis (DEF4G56, VWX9Y01, BCD2E34, FGH5I67)
--
-- Ordem: executar após 10-migration-frotas-alertas.sql e 05-seed-frotas.sql
-- Idempotente: sim (INSERT ... ON CONFLICT DO NOTHING usando um dedup por veiculo_id + data_alerta)

SET search_path TO frotas;

-- Dedup: usamos uma coluna calculada (ou um valor único) para evitar duplicatas.
-- A tabela não possui UNIQUE natural, então fazemos guarda com WHERE NOT EXISTS.

-- DEF4G56: 120.000 km (ultima manutencao aproximada em 2024-01-15)
INSERT INTO alertas_manutencao
    (veiculo_id, tipo_alerta, quilometragem_atual, limite_quilometragem, intervalo_meses,
     data_ultima_manutencao, status_notificacao, notificacao_id, data_alerta)
SELECT
    v.id, 'QUILOMETRAGEM', v.quilometragem, 50000, 3,
    '2024-01-15 08:00:00'::timestamp,
    'ENVIADA', 1001,
    '2024-03-01 16:00:00'::timestamp
FROM veiculos v
WHERE v.placa = 'DEF4G56'
  AND NOT EXISTS (
      SELECT 1 FROM alertas_manutencao a
      WHERE a.veiculo_id = v.id AND a.tipo_alerta = 'QUILOMETRAGEM'
        AND a.data_alerta = '2024-03-01 16:00:00'::timestamp
  );

-- VWX9Y01: 95.000 km
INSERT INTO alertas_manutencao
    (veiculo_id, tipo_alerta, quilometragem_atual, limite_quilometragem, intervalo_meses,
     data_ultima_manutencao, status_notificacao, notificacao_id, data_alerta)
SELECT
    v.id, 'QUILOMETRAGEM', v.quilometragem, 50000, 3,
    '2024-01-15 08:00:00'::timestamp,
    'ENVIADA', 1002,
    '2024-03-05 09:30:00'::timestamp
FROM veiculos v
WHERE v.placa = 'VWX9Y01'
  AND NOT EXISTS (
      SELECT 1 FROM alertas_manutencao a
      WHERE a.veiculo_id = v.id AND a.tipo_alerta = 'QUILOMETRAGEM'
        AND a.data_alerta = '2024-03-05 09:30:00'::timestamp
  );

-- BCD2E34: 78.000 km
INSERT INTO alertas_manutencao
    (veiculo_id, tipo_alerta, quilometragem_atual, limite_quilometragem, intervalo_meses,
     data_ultima_manutencao, status_notificacao, notificacao_id, data_alerta)
SELECT
    v.id, 'QUILOMETRAGEM', v.quilometragem, 50000, 3,
    '2024-01-15 08:00:00'::timestamp,
    'ENVIADA', 1003,
    '2024-02-28 11:15:00'::timestamp
FROM veiculos v
WHERE v.placa = 'BCD2E34'
  AND NOT EXISTS (
      SELECT 1 FROM alertas_manutencao a
      WHERE a.veiculo_id = v.id AND a.tipo_alerta = 'QUILOMETRAGEM'
        AND a.data_alerta = '2024-02-28 11:15:00'::timestamp
  );

-- FGH5I67: 150.000 km
INSERT INTO alertas_manutencao
    (veiculo_id, tipo_alerta, quilometragem_atual, limite_quilometragem, intervalo_meses,
     data_ultima_manutencao, status_notificacao, notificacao_id, data_alerta)
SELECT
    v.id, 'QUILOMETRAGEM', v.quilometragem, 50000, 3,
    '2024-01-15 08:00:00'::timestamp,
    'ENVIADA', 1004,
    '2024-03-10 14:45:00'::timestamp
FROM veiculos v
WHERE v.placa = 'FGH5I67'
  AND NOT EXISTS (
      SELECT 1 FROM alertas_manutencao a
      WHERE a.veiculo_id = v.id AND a.tipo_alerta = 'QUILOMETRAGEM'
        AND a.data_alerta = '2024-03-10 14:45:00'::timestamp
  );

-- FIXME: notificacao_id hardcoded para fins de demonstração
-- FIXME: data_ultima_manutencao aproximada (seed Clemente), deveria vir de manutencoes.data_manutencao
-- FIXME: em produção, api-notificacoes retorna o id real da notificação

-- Verificação
SELECT '=== Seed de alertas: verificação ===' AS info;

SELECT a.id, v.placa, a.tipo_alerta, a.quilometragem_atual, a.limite_quilometragem,
       a.status_notificacao, a.notificacao_id, a.data_alerta
FROM alertas_manutencao a
JOIN veiculos v ON v.id = a.veiculo_id
ORDER BY a.data_alerta;
