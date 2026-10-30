# Comércio Exterior Brasileiro (2024–2026): Data Warehouse em PostgreSQL & Dashboard Power BI

Pipeline ELT e modelagem dimensional (**Star Schema + Bridge Table**) em **PostgreSQL 18** sobre **8,15 milhões de registros** oficiais do MDIC (Comex Stat), com análise de exportação e importação por município, produto (SH4), país e bloco econômico no **Power BI**.

---

## Sobre o Projeto

Análise do comércio exterior brasileiro nos **24 meses fechados mais recentes da base (out/2024 a set/2026)**, com valores nominais em **US$ FOB** e peso líquido em **kg**. O ano de 2024 foi carregado integralmente no banco para garantir o cálculo correto de variação mensal (`DATEADD -1 month`) em outubro/2024.

- **Volume processado**: `8.156.398` linhas na tabela fato consolidada (`3.252.883` exportações + `4.903.515` importações).
- **Conferência de Qualidade (Data Quality)**: 100% de conciliação em quantidade de linhas, quilograma líquido e US$ FOB contra os arquivos oficiais de auditoria do MDIC (`EXP_TOTAIS_CONFERENCIA_MUN` e `IMP_TOTAIS_CONFERENCIA_MUN`).

---

## Arquitetura e Engenharia de Dados

```
Arquivos CSV (13 arquivos MDIC Comex Stat)
   │
   ▼
PostgreSQL — Schema `staging` (EL: Dados brutos como TEXT, tratamento de encoding e parser SQL para NCM_SH)
   │
   ▼
PostgreSQL — Schema `dw` (T: Views tipadas em Star Schema + Ponte N:N e testes de integridade referencial)
   │
   ▼
Power BI Desktop (Modo Importação, `dim_calendario` e tabela `_Medidas` em DAX, 5 páginas analíticas + 1 página de auditoria)
```

### Tecnologias Utilizadas

| Camada | Tecnologia |
|---|---|
| Banco de Dados & ELT | PostgreSQL 18 (`COPY`, CTEs, Views, `FILTER`, arrays) |
| Cliente SQL | DBeaver |
| Modelagem Dimensional | Star Schema (Kimball) + Bridge Table (`dbdiagram.io`) |
| Visualização & Analytics | Power BI Desktop, Power Query, DAX |
| Fonte de Dados | MDIC / Comex Stat (Base por Município SH4 + Tabelas de Correlação) |

---

## Fonte e Arquivos Utilizados (MDIC / Comex Stat)

Foram ingeridos **13 arquivos CSV** oficiais:

| Arquivo | Finalidade | Volume / Observação |
|---|---|---|
| `EXP_2024_MUN`, `EXP_2025_MUN`, `EXP_2026_MUN` | Fato de Exportação | `3.252.883` linhas no total (ASCII) |
| `IMP_2024_MUN`, `IMP_2025_MUN`, `IMP_2026_MUN` | Fato de Importação | `4.903.515` linhas no total (ASCII) |
| `EXP_TOTAIS_CONFERENCIA_MUN`, `IMP_TOTAIS_CONFERENCIA_MUN` | Auditoria / Reconciliação | Totais oficiais de 1997 a 2026 (filtrados para 2024–2026) |
| `NCM_SH` | Hierarquia de Produto (SH4, SH2 e Seção) | `6.620` linhas no nível SH6 (agrupado para `1.274` SH4) |
| `UF_MUN` | Nome do Município e UF | `5.570` municípios (codificação SECEX) |
| `UF` | Estado e Região | Padronização de nomes de macrorregiões |
| `PAIS` | Países e código ISO3 | `281` países |
| `PAIS_BLOCO` | Blocos Econômicos | `324` linhas distribuídas em `11` blocos econômicos |

---

## Modelagem de Dados (`staging` → `dw`)

![Diagrama do Modelo Estrela](imagens/diagrama.png)

### Schema `staging` (Camada Raw)
Todos os CSVs entram como `text` para preservar zeros à esquerda em códigos (`sh4`, `co_pais`, `co_mun`, `co_mes`) e evitar falhas de ingestão antes do tratamento.

### Schema `dw` (Camada Dimensional — Star Schema)

| View | Colunas | Linhas | Regra de Negócio / Origem |
|---|---|---|---|
| [`dw.fato_comex`](sql/05_fato_comex.sql) | `data, fluxo, sh4, co_pais, co_mun, kg_liquido, vl_fob` | `8.156.398` | `exp_mun UNION ALL imp_mun` com tipagem (`date`, `bigint`, `numeric`) |
| [`dw.dim_municipio`](sql/02_dim_municipio.sql) | `co_mun, no_mun, municipio_uf, sg_uf, no_uf, regiao` | `5.570` | `uf_mun LEFT JOIN uf` + rótulo composto `Município - UF` |
| [`dw.dim_produto`](sql/03_dim_produto.sql) | `sh4, no_sh4, produto, co_sh2, no_sh2, co_secao, no_secao` | `1.274` | `ncm_sh` deduplicado do nível SH6 para SH4 |
| [`dw.dim_pais`](sql/04_dim_pais_ponte_bloco.sql) | `co_pais, no_pais, iso3` | `281` | Dimensão de países |
| [`dw.ponte_pais_bloco`](sql/04_dim_pais_ponte_bloco.sql) | `co_pais, co_bloco, no_bloco` | `318` | Tabela ponte N:N (53 países pertencem a mais de um bloco, ex.: Alemanha em Europa e UE) |

> **Por que usar uma Bridge Table (`ponte_pais_bloco`)?**  
> Como 53 países pertencem a múltiplos blocos econômicos simultaneamente, colocar o bloco na fato ou na dimensão país duplicaria os valores em US$ FOB. A tabela ponte com filtro bidirecional controlado (`dim_pais` ↔ `ponte_pais_bloco`) permite filtrar qualquer bloco econômico sem inflar os totais.

---

## Problemas Encontrados e Tratamentos de Engenharia

1. **Aspas sem escape no arquivo `NCM_SH.csv`**: O arquivo bruto possui aspas duplas internas não escapadas que quebram o parser CSV nativo do comando `COPY` do PostgreSQL.
   - **Solução**: Ingestão da linha bruta inteira em `staging.ncm_sh_raw` usando delimitador de controle (`E'\x01'`) e separação determinística dos 16 campos via SQL (`string_to_array(trim(both '"' FROM linha), '";"')`), validando `cardinality(c) = 16` para todas as 6.620 linhas.
2. **Encoding Misto**: Tabelas auxiliares carregadas explicitamente com `ENCODING 'LATIN1'` para preservar acentuação; tabelas fato e de conferência em ASCII.
3. **Granularidade de Produto (SH6 → SH4)**: A tabela `NCM_SH` original está no nível SH6 (6.620 linhas), enquanto a fato municipal opera no nível SH4. Antes do `SELECT DISTINCT`, foi validado que cada código SH4 possui descrição, SH2 e Seção únicos (`1.274` produtos SH4, zero órfãos na fato).
4. **Homonímia de Municípios e Códigos Especiais**: Criação do atributo `municipio_uf` (`NO_MUN_MIN || ' - ' || SG_UF`) para distinguir municípios homônimos em estados diferentes. Códigos especiais oficiais (`9300000 - Exterior` e `9999999 - Não Declarado`) foram classificados na região `"Outros"` e mantidos para conciliação exata com o total oficial do MDIC.
5. **Integridade Referencial em `PAIS_BLOCO`**: Identificados 6 registros referenciando 5 códigos de países inexistentes em `PAIS` (`008, 106, 286, 579, 855`). Foram higienizados na view `dw.ponte_pais_bloco` após comprovação de que não possuem movimentação na fato.
6. **Correção de Contexto DAX no Ranking/Pareto**: Substituição de `ALLSELECTED` por `ALL` na coluna analisada dentro das medidas de `RANKX` e Pareto, garantindo que filtros visuais de *Top N* não alterem o denominador nem recalculem o ranking exibido.

---

## Validação e Auditoria dos Dados

Todos os testes de qualidade estão automatizados nos próprios scripts SQL e na página oculta **Validação** do arquivo `.pbix`:

| Fluxo | Ano | Linhas Carregadas | Valor Total (US$ FOB) | Conferência Oficial MDIC |
|---|---|---:|---:|---|
| Exportação | 2024 | 1.144.828 | US$ 337.046.161.710 | 100% (Linhas, KG e US$ FOB batem) |
| Exportação | 2025 | 1.207.088 | US$ 348.278.462.500 | 100% (Linhas, KG e US$ FOB batem) |
| Exportação | 2026 (jan–set) | 900.967 | US$ 284.654.368.793 | 100% (Linhas, KG e US$ FOB batem) |
| Importação | 2024 | 1.729.056 | US$ 262.869.606.174 | 100% (Linhas, KG e US$ FOB batem) |
| Importação | 2025 | 1.798.254 | US$ 280.208.433.825 | 100% (Linhas, KG e US$ FOB batem) |
| Importação | 2026 (jan–set) | 1.376.205 | US$ 222.258.509.601 | 100% (Linhas, KG e US$ FOB batem) |

---

## Principais Insights do Estudo (Out/2024 a Set/2026)

- **Balança Comercial (24 meses)**: Exportação de **US$ 715,0 bi**, Importação de **US$ 569,0 bi** e superávit acumulado de **US$ 145,9 bi**. Entre 2024 e 2025, a exportação cresceu **+3,3%** e a importação **+6,6%**.
- **Forte Concentração em Commodities (Pareto de Produtos)**: Apenas **38 produtos SH4** (de 1.274) concentram **80% de toda a exportação brasileira**. Petróleo bruto (`2709`), Soja (`1201`) e Minério de ferro (`2601`) respondem sozinhos por **34%** da pauta exportadora.
- **Concentração Geográfica (Pareto de Municípios)**: **220 municípios** concentram 80% da exportação (liderados pelo **Rio de Janeiro - RJ** com US$ 84,5 bi devido ao domicílio fiscal de petroleiras, seguido por Santos - SP e Canaã dos Carajás - PA), enquanto na importação a concentração é ainda maior: apenas **102 municípios** respondem por 80% do volume (Itajaí - SC e Manaus - AM na liderança).
- **Geopolítica e Parceiros Comerciais**: A **China** é o principal destino (US$ 202,6 bi — quase 3x o volume dos EUA) e gera o maior superávit bilateral (**US$ 55,7 bi**). Com os **EUA**, 2º maior parceiro individual, o Brasil registra déficit de **US$ -10,8 bi**, atrás apenas dos déficits com **Rússia** (US$ -16,3 bi, fertilizantes/combustíveis) e **Alemanha** (US$ -15,4 bi).
- **Sazonalidade**: As exportações apresentam retração em janeiro/fevereiro e forte salto em março (**+26,3% em mar/25** e **+20,9% em mar/26**), acompanhando o escoamento da safra agrícola.

---

## Telas do Dashboard

### 1. Visão Geral
![Visão Geral](imagens/01-visao-geral.png)

### 2. Análise de Municípios (Ranking & Curva de Pareto 80%)
![Municípios](imagens/02-municipios.png)

### 3. Análise de Produtos SH4 (Ranking & Curva de Pareto 80%)
![Produtos SH4](imagens/03-produtos-sh4.png)

### 4. Desvio Mensal (MoM Absoluto e Percentual)
![Desvio Mensal](imagens/04-desvio-mensal.png)

### 5. Parceiros Comerciais e Blocos Econômicos
![Parceiros Comerciais](imagens/05-parceiros-comerciais.png)

---

## Estrutura do Repositório

```
├── sql/
│   ├── 01_carga_staging.sql           # Criação de schemas, tabelas staging, COPY e parser SQL do NCM_SH
│   ├── 02_dim_municipio.sql           # View dw.dim_municipio e testes de unicidade/região
│   ├── 03_dim_produto.sql             # View dw.dim_produto (agregação SH6 -> SH4) e teste de órfãos
│   ├── 04_dim_pais_ponte_bloco.sql    # Views dw.dim_pais e dw.ponte_pais_bloco (higienização de códigos)
│   └── 05_fato_comex.sql              # View dw.fato_comex e reconciliação oficial contra o MDIC
├── dashboard/
│   ├── comex_dashboard.pbix           # Arquivo Power BI completo (modelo, DAX, 5 páginas + validação)
│   └── comex_dashboard.pdf            # Exportação em PDF das páginas do dashboard
├── docs/
│   └── Documentacao_Dashboard_Comex.pdf # Documentação técnica detalhada do projeto
├── imagens/                           # Diagrama do modelo estrela e capturas das páginas do relatório
└── README.md
```

---

## Como Reproduzir do Zero

1. Baixe os 13 arquivos CSV no portal [Comex Stat (MDIC)](https://comexstat.mdic.gov.br/) (Base por Municípios SH4 de 2024 a 2026 + Tabelas de Correlação e Conferência) e salve em `C:\comex\dados\`.
2. Crie um banco de dados chamado `comex` no **PostgreSQL**.
3. Execute os scripts da pasta [`sql/`](sql/) na ordem numérica (`01` a `05`).
4. Abra o arquivo [`dashboard/comex_dashboard.pbix`](dashboard/comex_dashboard.pbix) no **Power BI Desktop** (caso seu servidor PostgreSQL não seja `localhost`, ajuste o endereço em *Transformar dados > Configurações da fonte de dados*).
