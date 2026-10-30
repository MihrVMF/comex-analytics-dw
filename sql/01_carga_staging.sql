-- =========================================================
-- 01 - CARGA STAGING
-- Banco: comex | Fonte: MDIC/Comex Stat | Pasta: C:\comex\dados\
-- Auxiliares em Latin-1; fatos e conferência em ASCII.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;

-- UF
CREATE TABLE staging.uf (
    co_uf text, sg_uf text, no_uf text, no_regiao text
);
COPY staging.uf FROM 'C:\comex\dados\UF.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true, ENCODING 'LATIN1');

-- PAIS
CREATE TABLE staging.pais (
    co_pais text, co_pais_ison3 text, co_pais_isoa3 text,
    no_pais text, no_pais_ing text, no_pais_esp text
);
COPY staging.pais FROM 'C:\comex\dados\PAIS.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true, ENCODING 'LATIN1');

-- PAIS_BLOCO
CREATE TABLE staging.pais_bloco (
    co_pais text, co_bloco text, no_bloco text,
    no_bloco_ing text, no_bloco_esp text
);
COPY staging.pais_bloco FROM 'C:\comex\dados\PAIS_BLOCO.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true, ENCODING 'LATIN1');

-- UF_MUN
CREATE TABLE staging.uf_mun (
    co_mun_geo text, no_mun text, no_mun_min text, sg_uf text
);
COPY staging.uf_mun FROM 'C:\comex\dados\UF_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true, ENCODING 'LATIN1');

-- CONFERÊNCIA (totais oficiais por ano, 1997-2026)
CREATE TABLE staging.exp_conferencia (
    arquivo text, co_ano text, kg_liquido text, vl_fob text, numero_linhas text
);
COPY staging.exp_conferencia FROM 'C:\comex\dados\EXP_TOTAIS_CONFERENCIA_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);

CREATE TABLE staging.imp_conferencia (
    arquivo text, co_ano text, kg_liquido text, vl_fob text, numero_linhas text
);
COPY staging.imp_conferencia FROM 'C:\comex\dados\IMP_TOTAIS_CONFERENCIA_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);

-- NCM_SH: o arquivo tem aspas sem escape dentro do texto, o que quebra o COPY padrão.
-- Solução: carregar a linha inteira e separar os campos por '";"' via SQL.
CREATE TABLE staging.ncm_sh_raw (linha text);
COPY staging.ncm_sh_raw FROM 'C:\comex\dados\NCM_SH.csv'
WITH (FORMAT csv, DELIMITER E'\x01', QUOTE E'\x02', HEADER true, ENCODING 'LATIN1');

CREATE TABLE staging.ncm_sh AS
WITH l AS (
    SELECT string_to_array(trim(both '"' FROM linha), '";"') AS c
    FROM staging.ncm_sh_raw
)
SELECT
    c[1]  AS co_sh6,
    c[2]  AS no_sh6_por,
    c[3]  AS no_sh6_esp,
    c[4]  AS no_sh6_ing,
    c[5]  AS co_sh4,
    c[6]  AS no_sh4_por,
    c[7]  AS no_sh4_esp,
    c[8]  AS no_sh4_ing,
    c[9]  AS co_sh2,
    c[10] AS no_sh2_por,
    c[11] AS no_sh2_esp,
    c[12] AS no_sh2_ing,
    c[13] AS co_ncm_secrom,
    c[14] AS no_sec_por,
    c[15] AS no_sec_esp,
    c[16] AS no_sec_ing,
    cardinality(c) AS qtd_campos
FROM l;

-- FATOS DE EXPORTAÇÃO (2024, 2025 e 2026)
CREATE TABLE staging.exp_mun (
    co_ano text, co_mes text, sh4 text, co_pais text,
    sg_uf_mun text, co_mun text, kg_liquido text, vl_fob text
);
COPY staging.exp_mun FROM 'C:\comex\dados\EXP_2024_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);
COPY staging.exp_mun FROM 'C:\comex\dados\EXP_2025_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);
COPY staging.exp_mun FROM 'C:\comex\dados\EXP_2026_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);

-- FATOS DE IMPORTAÇÃO (2024, 2025 e 2026)
CREATE TABLE staging.imp_mun (
    co_ano text, co_mes text, sh4 text, co_pais text,
    sg_uf_mun text, co_mun text, kg_liquido text, vl_fob text
);
COPY staging.imp_mun FROM 'C:\comex\dados\IMP_2024_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);
COPY staging.imp_mun FROM 'C:\comex\dados\IMP_2025_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);
COPY staging.imp_mun FROM 'C:\comex\dados\IMP_2026_MUN.csv'
WITH (FORMAT csv, DELIMITER ';', QUOTE '"', HEADER true);
