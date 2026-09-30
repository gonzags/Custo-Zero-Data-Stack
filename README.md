# Olist E-commerce Analytics - Pipeline Local com dbt + DuckDB

Pipeline analitico completo, rodando 100% local, sem custo de nuvem: DuckDB como warehouse embarcado, dbt-core para transformacao, testes e documentacao, com integracao continua via GitHub Actions.

O projeto simula o cenario de uma empresa de e-commerce processando pedidos, clientes, produtos e pagamentos, usando o Brazilian E-Commerce Public Dataset by Olist, disponivel no Kaggle (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

## Stack

DuckDB - warehouse analitico embarcado (um unico arquivo, sem infraestrutura de servidor).
dbt-core - transformacao, testes de qualidade e documentacao, via CLI, sem dependencia do dbt Cloud.
GitHub Actions - build e validacao automatica a cada push ou Pull Request.

## Arquitetura

CSVs brutos (data_raw/)
        read_csv_auto (DuckDB, sources externas)
staging (stg_*): limpeza, cast de tipos, padronizacao de texto
intermediate (int_*): logica de negocio (pivot de pagamentos, deduplicacao por CEP)
marts (dim_/fct_): star schema com dim_customers, dim_products, fct_orders
GitHub Actions: valida build e testes a cada push, sobre uma amostra dos dados

## Por que essas decisoes tecnicas

### DuckDB no lugar de um data warehouse de nuvem

Warehouse analitico columnar embarcado, sem custo de infraestrutura, com performance mais que suficiente para o volume de um projeto de portfolio. Facilmente substituivel por Snowflake, BigQuery ou Postgres em um cenario de producao, sem reescrever a logica dos modelos.

### Sources externas em vez de dbt seed para os dados transacionais

Os 8 CSVs grandes do Kaggle (customers, orders, order_items, order_payments, products, sellers, order_reviews, geolocation) nao sao commitados no Git. Eles ficam em data_raw/ (ignorado no .gitignore) e sao lidos diretamente pelo DuckDB via read_csv_auto, declarados como sources do dbt com meta.external_location.

dbt seed foi reservado so para tabelas de referencia pequenas e estaticas, exatamente o caso de product_category_name_translation (traducao de categoria) e geolocation_state_pattern (nome do estado por UF). Versionar dado transacional no Git nao escala e nao reflete como um pipeline real se comporta.

### Variavel data_raw_path em vez de caminho fixo

O caminho da pasta de dados brutos e parametrizado (vars.data_raw_path no dbt_project.yml), permitindo apontar para pastas diferentes conforme o ambiente (local, CI) sem editar o sources.yml.

## Modelagem dimensional

Camada staging, modelos stg_olist__*, grao espelha a fonte, observacao: limpeza e cast de tipos, sem logica de negocio.

Camada intermediate, modelo int_order_payments_pivoted, grao 1 linha por pedido, observacao: pivota valores por forma de pagamento.

Camada intermediate, modelo int_geolocation_by_zip, grao 1 linha por CEP, observacao: resolve duplicacao de aproximadamente 53 linhas por CEP na fonte.

Camada marts, modelo dim_customers, grao 1 linha por cliente, observacao: enriquecida com coordenadas e nome do estado via int_geolocation_by_zip.

Camada marts, modelo dim_products, grao 1 linha por produto, observacao: categoria traduzida de portugues para ingles.

Camada marts, modelo fct_orders, grao 1 linha por item de pedido, observacao: ver nota de grao abaixo.

### Nota de grao: por que int_order_payments_pivoted nao e juntado em fct_orders

int_order_payments_pivoted esta no grao de pedido. fct_orders esta no grao de item de pedido, necessario para product_key fazer sentido na fact. Juntar os dois causaria fan-out: um pedido com 3 itens repetiria o mesmo valor de pagamento em 3 linhas, e qualquer sum() posterior infla o resultado em 3x, um erro silencioso, sem gerar nenhum aviso. A tabela de pagamentos pivotados fica disponivel separadamente, para analises no grao de pedido.

### Nota sobre int_geolocation_by_zip

A tabela de geolocalizacao tem, em media, cerca de 53 linhas por CEP (1.000.163 linhas para 19.015 CEPs distintos). Resolvido via avg() das coordenadas e max() para cidade e estado, uma escolha deterministica, nao estatisticamente a mais correta. Uma melhoria futura seria usar mode() para pegar o valor mais frequente.

42 linhas, cerca de 0,004% do total, tinham coordenadas fora do intervalo geografico do Brasil, filtradas antes da agregacao, dado o volume irrisorio.

## Macros customizadas

pad_zip_code: padroniza CEP como texto de 5 digitos, evitando perda do zero a esquerda que ocorreria com inferencia de tipo inteiro.

pivot_sum: gera dinamicamente sum(case when...) para uma lista de valores, eliminando repeticao manual do pivot de formas de pagamento.

is_valid_brazil_coordinates: retorna a condicao booleana de latitude e longitude dentro dos limites do Brasil, reutilizavel, com limites configuraveis via argumento.

## Testes de qualidade implementados

Genericos do dbt: unique, not_null, accepted_values, relationships.
dbt_utils.accepted_range para valores monetarios nao negativos.
dbt_utils.unique_combination_of_columns para chaves compostas: order_id mais order_item_id, order_id mais payment_sequential, review_id mais order_id.
Teste singular assert_payments_pivot_reconciles.sql, validando que a soma de pagamentos nao se perde no pivot da camada intermediate.
relationships em fct_orders garantindo que toda linha da fact tem uma dimensao correspondente, sem chaves orfas.

## CI/CD com GitHub Actions

A cada push ou Pull Request na branch main, o workflow .github/workflows/dbt-ci.yml sobe uma VM Ubuntu limpa, instala Python e as dependencias do requirements.txt, e roda dbt deps, dbt seed e dbt build (models e testes).

Como os dados brutos completos nao sao versionados, o CI roda sobre uma amostra relacional, na pasta data_raw_sample, um subconjunto de pedidos e todas as entidades relacionadas a eles (clientes, itens, produtos, vendedores, pagamentos, reviews), preservando a integridade referencial entre as tabelas. A amostra foi gerada via consulta SQL sobre o warehouse completo, nao por corte isolado de cada arquivo, ja que um corte independente por arquivo quebraria os relacionamentos entre order_id, customer_id e product_id, fazendo os testes relationships falharem por amostragem, nao por erro real de modelagem.

## Estrutura de pastas

ecommerce-analytics-olist
.github/workflows/dbt-ci.yml, o CI que roda dbt deps, seed e build
data_raw, os CSVs brutos do Kaggle, nao versionado
data_raw_sample, a amostra relacional usada pelo CI
dbt_project
    dbt_project.yml
    profiles.yml, commitado porque DuckDB nao usa credenciais
    packages.yml, com o dbt_utils
    seeds, tabelas de referencia pequenas e estaticas
    macros
        generate_schema_name.sql, schemas sem concatenacao com o default
        pad_zip_code.sql
        pivot_sum.sql
        is_valid_brazil_coordinates.sql
    models
        staging, sources externas e limpeza um para um com a fonte
        intermediate, logica de negocio como pivot e deduplicacao
        marts, star schema com dim e fct
    tests, teste singular de reconciliacao
requirements.txt

## Como rodar localmente

Criar e ativar o ambiente virtual, instalar as dependencias com pip install -r requirements.txt.

Entrar na pasta dbt_project e rodar, em sequencia: dbt deps --profiles-dir ., dbt seed --profiles-dir ., dbt build --profiles-dir .

Para documentacao e lineage: dbt docs generate --profiles-dir . seguido de dbt docs serve --profiles-dir .

Os CSVs completos precisam ser baixados do Kaggle (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) e colocados em data_raw/, com os nomes originais (olist_customers_dataset.csv, olist_orders_dataset.csv, e assim por diante).

## Decisoes de projeto registradas para revisao tecnica

Sources externas versus seeds: dado transacional nao e versionado, so tabelas de referencia pequenas viram seed.

Grao da fact: fct_orders no grao de item de pedido, nao de pedido, decisao que evita perder a granularidade de produto, ao custo de nao incorporar diretamente os dados de pagamento.

Deduplicacao de geolocalizacao: max() para texto, deterministico mas nao necessariamente o mais correto estatisticamente, e avg() para coordenadas.

Amostra de CI construida via relacao, nao corte isolado por arquivo, para preservar integridade referencial nos testes.

## Proximos passos possiveis

Trocar data_raw local por leitura direta de um bucket S3 ou GCS, a extensao httpfs do DuckDB, ja habilitada no profiles.yml, torna essa troca direta.

Reintroduzir uma camada de consumo ou visualizacao, se necessario no futuro.

Base para o Projeto 3 do portfolio, Data Quality, Observability e CI/CD com SQLFluff, dbt-checkpoint e Elementary Data, e para o Projeto 4, orquestracao com Dagster.