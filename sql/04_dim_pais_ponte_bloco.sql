CREATE OR REPLACE VIEW dw.dim_pais AS
SELECT
    co_pais,
    no_pais,
    co_pais_isoa3 AS iso3
FROM staging.pais;

-- 6 registros de PAIS_BLOCO referenciam 5 códigos inexistentes em PAIS
-- (008, 106, 286, 579, 855); excluídos. Sem impacto: não ocorrem na fato.
CREATE OR REPLACE VIEW dw.ponte_pais_bloco AS
SELECT
    b.co_pais,
    b.co_bloco,
    b.no_bloco
FROM staging.pais_bloco b
WHERE b.co_pais IN (SELECT co_pais FROM staging.pais);