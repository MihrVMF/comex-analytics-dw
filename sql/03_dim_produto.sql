CREATE VIEW dw.dim_produto AS
SELECT DISTINCT
    co_sh4                         AS sh4,
    no_sh4_por                     AS no_sh4,
    co_sh4 || ' - ' || no_sh4_por  AS produto,
    co_sh2,
    no_sh2_por                     AS no_sh2,
    co_ncm_secrom                  AS co_secao,
    no_sec_por                     AS no_secao
FROM staging.ncm_sh;

-- Conferência 1: chave única (deve ser 1274 / 1274)
SELECT count(*) AS linhas, count(DISTINCT sh4) AS sh4_distintos
FROM dw.dim_produto;

-- Conferência 2: SH4 da fato sem par na dimensão (deve ser 0)
SELECT count(DISTINCT f.sh4) AS sh4_orfaos
FROM (SELECT sh4 FROM staging.exp_mun
      UNION
      SELECT sh4 FROM staging.imp_mun) f
LEFT JOIN dw.dim_produto p ON p.sh4 = f.sh4
WHERE p.sh4 IS NULL;