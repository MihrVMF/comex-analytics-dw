# Comércio Exterior Brasileiro (2024 a 2026)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white) ![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black) ![DAX](https://img.shields.io/badge/DAX-F2C811?style=for-the-badge&logo=powerbi&logoColor=black) ![SQL](https://img.shields.io/badge/SQL-Data_Warehouse-316192?style=for-the-badge)

Painel analítico de comércio exterior desenvolvido com base nos dados abertos do Comex Stat (MDIC), consolidando exportações e importações brasileiras por município e produto (nível SH4) na série histórica de **outubro de 2024 a setembro de 2026** (os 24 meses fechados mais recentes). Valores expressos em US$ FOB.

O projeto une engenharia de dados em PostgreSQL (carga bruta, limpeza via SQL e modelagem dimensional) e desenvolvimento de dashboards no Power BI, oferecendo respostas rápidas sobre a balança comercial, os principais municípios exportadores e os fluxos comerciais com parceiros internacionais.

* **Arquivo Power BI (.pbix):** [dashboard/comex_dashboard.pbix](dashboard/comex_dashboard.pbix)
* **Documentação em PDF:** [docs/Documentacao_Dashboard_Comex.pdf](docs/Documentacao_Dashboard_Comex.pdf)
* **Visualização das Telas (PDF):** [dashboard/comex_dashboard.pdf](dashboard/comex_dashboard.pdf)
* **Base de dados bruta dos CSVs:** [Disponível na aba Releases (v1.0)](https://github.com/MihrVMF/comex-analytics-dw/releases/tag/v1.0)

![Visão Geral](imagens/01-visao-geral.png)

## O problema que o projeto resolve

A base oficial do Comex Stat publica mensalmente arquivos volumosos em formato CSV que somam mais de 8 milhões de registros de movimentação comercial, além de dezenas de tabelas de correlação. Consumir esses arquivos diretamente no Power BI sem tratamento prévio costuma travar o relatório, perder códigos com zeros à esquerda e gerar duplicidade em cruzamentos de blocos econômicos.

Para solucionar esse problema, estruturei um fluxo em duas etapas no PostgreSQL: primeiro recebi os dados brutos no schema `staging` sem alterações; em seguida, construí o schema `dw` com uma modelagem dimensional Star Schema (tabelas fato e dimensão em views analíticas). Dessa forma, o Power BI consome um modelo limpo, rápido e com integridade referencial garantida.

## Principais insights encontrados

* **Superávit comercial:** Nos 24 meses analisados, o Brasil exportou **US$ 715,0 bilhões** e importou **US$ 569,0 bilhões**, gerando um saldo positivo de **US$ 145,9 bilhões**.
* **Alta concentração de produtos:** Apenas 38 produtos na classificação SH4 respondem por 80% do total exportado. Soja, óleos brutos de petróleo e minérios de ferro somam sozinhos 34% de todas as exportações brasileiras.
* **Polos exportadores e importadores:** São necessários 220 municípios para atingir 80% das exportações. Na importação a concentração é ainda maior, bastando 102 municípios para cobrir 80% do volume nacional (com destaque para polos portuários e industriais como Itajaí e Manaus).
* **Liderança por domicílio fiscal:** O município do Rio de Janeiro lidera as exportações com US$ 84,5 bilhões por sediar grandes petroleiras, já que a base oficial adota o endereço fiscal da matriz da empresa declarante.
* **Dinâmica com parceiros comerciais:** A China é o principal parceiro e o maior gerador de superávit do Brasil (US$ 202,6 bilhões em compras e US$ 55,7 bilhões de saldo favorável). Com os Estados Unidos, segundo maior destino, o saldo comercial é deficitário em US$ 10,8 bilhões.
* **Comportamento sazonal:** As exportações apresentam queda no primeiro bimestre e aceleram fortemente a partir de março (altas de 26,3% em março de 2025 e 20,9% em março de 2026), acompanhando o calendário de escoamento da safra agrícola.

## Telas do Painel

### 1. Visão Geral
Painel executivo com a balança comercial consolidada dos 24 meses, total de exportações, importações, saldo comercial em US$ FOB e gráfico de desvio mês a mês.
![Visão Geral](imagens/01-visao-geral.png)

### 2. Análise por Municípios
Ranking dos principais polos municipais exportadores e importadores, mapas de calor por estado e proporção de representatividade regional.
![Municípios](imagens/02-municipios.png)

### 3. Produtos (SH4)
Visão detalhada por código e descrição de mercadorias no nível SH4, distribuição por seções tarifárias e curva de concentração de itens exportados.
![Produtos SH4](imagens/03-produtos-sh4.png)

### 4. Desvio Mensal
Acompanhamento comparativo entre meses consecutivos, evolução do superávit comercial e sinalização visual de oscilações anormais no volume transacionado.
![Desvio Mensal](imagens/04-desvio-mensal.png)

### 5. Parceiros Comerciais
Fluxo financeiro por países e blocos econômicos (Mercosul, União Europeia, NAFTA, entre outros) e saldo bilateral de cada parceiro.
![Parceiros Comerciais](imagens/05-parceiros-comerciais.png)

## Modelagem do Banco de Dados (Star Schema)

A camada analítica no PostgreSQL segue os princípios de modelagem dimensional de Ralph Kimball. O modelo estrela foi estruturado para suportar o volume de mais de 8,1 milhões de linhas na fato sem perda de performance.

![Modelo de dados](imagens/diagrama.png)

### Estrutura das Tabelas e Views no PostgreSQL

* **Camada Staging (`schema staging`):**
  * Tabelas brutas importadas via comando `COPY` a partir dos arquivos CSV originais do MDIC (`staging.exp_mun` com 3,25 milhões de linhas e `staging.imp_mun` com 4,90 milhões de linhas).
  * Todos os campos preservados em texto para evitar quebras por formatação e permitir limpeza controlada via queries SQL.

* **Tabela Fato (`dw.fato_comex`):**
  * Consolidação unificada de exportação e importação via `UNION ALL`, somando **8.156.398 linhas**.
  * Granularidade da fato: uma linha por mês, fluxo comercial (Exportação ou Importação), produto (SH4), país e município de origem ou destino.
  * Colunas de métrica: `kg_liquido` (peso em quilogramas) e `vl_fob` (valor monetário em dólares).

* **Tabelas Dimensão (`schema dw`):**
  * `dw.dim_municipio`: 5.570 municípios brasileiros tratados com chave SECEX, nome corrigido, estado e região geográfica (tratando homônimos entre diferentes estados com o padrão "Nome do Município (UF)").
  * `dw.dim_produto`: 1.274 produtos agregados no nível SH4 a partir do cadastro original em SH6, incluindo código e nome do capítulo (SH2) e da seção tarifária internacional.
  * `dw.dim_pais`: 281 países normalizados com nomes em português e códigos oficiais ISO Alpha 3.
  * `dw.ponte_pais_bloco`: tabela ponte criada especificamente para resolver o relacionamento de muitos para muitos entre países e blocos econômicos sem duplicar os valores das transações na fato. 53 países pertencem a mais de um bloco comercial (a exemplo da Alemanha, que integra a União Europeia e o continente europeu). Essa ponte garante a filtragem correta no Power BI sem inflar a balança comercial.
  * `dim_calendario`: gerada via DAX com marcação de tabela de data oficial para dar suporte aos cálculos de inteligência temporal.

## Desafios de Engenharia de Dados e Soluções em SQL

* **Aspas sem escape no cadastro de produtos:** O arquivo oficial `NCM_SH` possuía aspas duplas desbalanceadas no meio das descrições de mercadorias, causando falha no comando `COPY` tradicional do PostgreSQL. Carreguei o arquivo em uma coluna bruta única e utilizei funções de string em SQL (`split_part`) para segmentar com segurança os 16 campos das 6.620 linhas.
* **Padronização de encodings:** Os arquivos de movimentação estavam codificados em ASCII, enquanto as tabelas auxiliares de municípios e produtos utilizavam Latin-1. Configurei a leitura de cada arquivo com sua codificação correspondente para preservar todos os caracteres acentuados.
* **Preservação de zeros à esquerda:** Códigos de municípios, países, meses e SH4 foram modelados e tipados como texto no banco para evitar a perda de dígitos iniciais (como municípios iniciados por zero).
* **Higienização de registros órfãos:** Na tabela oficial de blocos econômicos, identifiquei 5 códigos de países inexistentes na tabela mestre de países (códigos 008, 106, 286, 579 e 855). Foram excluídos da tabela ponte no SQL sem qualquer impacto na integridade, já que nenhum deles possuía movimentações na fato.

## Validação e Qualidade dos Dados

Para garantir precisão contábil idêntica à dos relatórios oficiais do Ministério do Desenvolvimento, Indústria, Comércio e Serviços (MDIC), validei cada etapa da carga e modelagem comparando os resultados do PostgreSQL e do Power BI com os arquivos de conferência oficiais:

| Fluxo | Ano | Linhas na Fato | Volume em Dólares (US$ FOB) | Status da Validação |
|---|---|---:|---:|---|
| **Exportação** | 2024 | 1.144.828 | 337.046.161.710 | Batimento exato (linhas, KG e US$) |
| **Exportação** | 2025 | 1.207.088 | 348.278.462.500 | Batimento exato (linhas, KG e US$) |
| **Exportação** | 2026 (jan a set) | 900.967 | 284.654.368.793 | Batimento exato (linhas, KG e US$) |
| **Importação** | 2024 | 1.729.056 | 262.869.606.174 | Batimento exato (linhas, KG e US$) |
| **Importação** | 2025 | 1.798.254 | 280.208.433.825 | Batimento exato (linhas, KG e US$) |
| **Importação** | 2026 (jan a set) | 1.376.205 | 222.258.509.601 | Batimento exato (linhas, KG e US$) |

* As 8.156.398 linhas da view `dw.fato_comex` batem integralmente com os totais importados no Power BI.
* A consistência do total dos 24 meses foi auditada entre todas as páginas do relatório para certificar que filtros de Top N e ranking não distorcessem o totalizador geral.

## Tecnologias Utilizadas

* **Banco de Dados:** PostgreSQL (estruturação dos schemas `staging` e `dw`, tabelas e views analíticas).
* **Linguagem SQL:** Carga volumosa de dados, limpeza de caracteres especiais, joins dimensionais e conciliação de totais.
* **Power BI:** Modelagem em esquema estrela, relacionamento com tabela ponte, medidas em DAX e construção visual interativa.

## Arquivos do Projeto

| Arquivo / Pasta | Conteúdo |
|---|---|
| `sql/01_carga_staging.sql` | Criação das tabelas do schema `staging` e script de carga dos arquivos CSV |
| `sql/02_dim_municipio.sql` | Construção da view `dw.dim_municipio` com tratamentos de texto e UFs |
| `sql/03_dim_produto.sql` | Construção da view `dw.dim_produto` agregando NCM no nível SH4 |
| `sql/04_dim_pais_ponte_bloco.sql` | Criação das views `dw.dim_pais` e `dw.ponte_pais_bloco` |
| `sql/05_fato_comex.sql` | Criação da view `dw.fato_comex` consolidando exportações e importações |
| `dashboard/comex_dashboard.pbix` | Relatório completo do Power BI com o modelo semântico e as 5 páginas |
| `dashboard/comex_dashboard.pdf` | Exportação em PDF de todas as páginas do painel |
| `docs/Documentacao_Dashboard_Comex.pdf` | Documentação técnica original do projeto |

## Como reproduzir o projeto localmente

1. **Configuração do Banco no PostgreSQL:**
   * Crie uma base chamada `comex`.
   * Baixe os arquivos CSV na [aba Releases do repositório](https://github.com/MihrVMF/comex-analytics-dw/releases/tag/v1.0) e extraia na pasta `C:\comex\dados\`.
   * Execute os scripts da pasta `sql/` na sequência numérica (de `01` até `05`).

2. **Abrir o Painel no Power BI:**
   * Abra o arquivo [dashboard/comex_dashboard.pbix](dashboard/comex_dashboard.pbix) no Power BI Desktop.
   * Se o seu PostgreSQL estiver em outra porta ou servidor, ajuste a conexão em: *Transformar dados > Configurações da fonte de dados*.
