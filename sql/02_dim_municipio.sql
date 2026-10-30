CREATE VIEW dw.dim_municipio AS
SELECT
    m.co_mun_geo                       AS co_mun,
    m.no_mun_min                       AS no_mun,
    m.no_mun_min || ' - ' || m.sg_uf   AS municipio_uf,
    m.sg_uf,
    u.no_uf,
    CASE upper(trim(u.no_regiao))
        WHEN 'REGIAO NORTE'        THEN 'Norte'
        WHEN 'REGIAO NORDESTE'     THEN 'Nordeste'
        WHEN 'REGIAO SUDESTE'      THEN 'Sudeste'
        WHEN 'REGIAO SUL'          THEN 'Sul'
        WHEN 'REGIAO CENTRO OESTE' THEN 'Centro-Oeste'
        ELSE 'Outros'
    END                                AS regiao
FROM staging.uf_mun m
LEFT JOIN staging.uf u ON u.sg_uf = m.sg_uf;

-- Conferência 1: chave única e nenhum município sem UF
SELECT count(*)                               AS linhas,
       count(DISTINCT co_mun)                 AS co_mun_distintos,
       count(*) FILTER (WHERE no_uf IS NULL)  AS sem_uf
FROM dw.dim_municipio;

-- Conferência 2: limpeza das regiões
SELECT regiao, count(*) AS municipios
FROM dw.dim_municipio
GROUP BY regiao
ORDER BY municipios DESC;