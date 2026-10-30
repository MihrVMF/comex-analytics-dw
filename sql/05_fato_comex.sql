CREATE VIEW dw.fato_comex AS
SELECT make_date(co_ano::int, co_mes::int, 1) AS data,
       'Exportação'::text                     AS fluxo,
       sh4, co_pais, co_mun,
       kg_liquido::bigint                     AS kg_liquido,
       vl_fob::numeric                        AS vl_fob
FROM staging.exp_mun
UNION ALL
SELECT make_date(co_ano::int, co_mes::int, 1),
       'Importação'::text,
       sh4, co_pais, co_mun,
       kg_liquido::bigint,
       vl_fob::numeric
FROM staging.imp_mun;

-- Conferência 1: totais da VIEW x arquivos de conferência (tudo true)
WITH f AS (
    SELECT fluxo, extract(year FROM data)::int AS ano,
           count(*) AS linhas, sum(kg_liquido) AS kg, sum(vl_fob) AS fob
    FROM dw.fato_comex
    GROUP BY 1, 2
),
c AS (
    SELECT 'Exportação' AS fluxo, co_ano::int AS ano, numero_linhas::numeric AS linhas,
           kg_liquido::numeric AS kg, vl_fob::numeric AS fob
    FROM staging.exp_conferencia
    UNION ALL
    SELECT 'Importação', co_ano::int, numero_linhas::numeric,
           kg_liquido::numeric, vl_fob::numeric
    FROM staging.imp_conferencia
)
SELECT f.fluxo, f.ano,
       f.linhas = c.linhas AS ok_linhas,
       f.kg     = c.kg     AS ok_kg,
       f.fob    = c.fob    AS ok_fob
FROM f JOIN c USING (fluxo, ano)
ORDER BY 1, 2;

-- Conferência 2: período e municípios órfãos (órfãos = 0)
SELECT min(f.data) AS data_min,
       max(f.data) AS data_max,
       count(DISTINCT f.co_mun) FILTER (WHERE m.co_mun IS NULL) AS mun_orfaos
FROM dw.fato_comex f
LEFT JOIN dw.dim_municipio m ON m.co_mun = f.co_mun;