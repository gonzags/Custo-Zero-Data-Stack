# Olist E-commerce Analytics — Pipeline Local com dbt + DuckDB

Pipeline analítico completo, rodando 100% local, sem custo de nuvem: DuckDB como warehouse embarcado, dbt-core para transformação, testes e documentação, com integração contínua via GitHub Actions.

O projeto simula o cenário de uma empresa de e-commerce processando pedidos, clientes, produtos e pagamentos, usando o Brazilian E-Commerce Public Dataset by Olist, disponível no Kaggle (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

## Stack

- **DuckDB** — warehouse analítico embarcado (um único arquivo, sem infraestrutura de servidor).
- **dbt-core** — transformação, testes de qualidade e documentação, via CLI, sem dependência do dbt Cloud.
- **GitHub Actions** — build e validação automática a cada push ou Pull Request.

## Arquitetura

```
CSVs brutos (data_raw/)
        ↓ read_csv_auto (DuckDB, sources externas)
staging (stg_*): limpeza, cast de tipos, padronização de texto
intermediate (int_*): lógica de negócio (pivot de pagamentos, deduplicação por CEP)
marts (dim_/fct_): star schema com dim_customers, dim_products, fct_orders
GitHub Actions: valida build e testes a cada push, sobre uma amostra dos dados
```

## Por que essas decisões técnicas

### DuckDB no lugar de um data warehouse de nuvem

Warehouse analítico colunar embarcado, sem custo de infraestrutura, com performance mais que suficiente para o volume de um projeto de portfólio. Facilmente substituível por Snowflake, BigQuery ou Postgres em um cenário de produção, sem reescrever a lógica dos modelos.

### Sources externas em vez de dbt seed para os dados transacionais

Os 8 CSVs grandes do Kaggle (`customers`, `orders`, `order_items`, `order_payments`, `products`, `sellers`, `order_reviews`, `geolocation`) não são commitados no Git. Eles ficam em `data_raw/` (ignorado no `.gitignore`) e são lidos diretamente pelo DuckDB via `read_csv_auto`, declarados como sources do dbt com `meta.external_location`.

`dbt seed` foi reservado só para tabelas de referência pequenas e estáticas — exatamente o caso de `product_category_name_translation` (tradução de categoria) e `geolocation_state_pattern` (nome do estado por UF). Versionar dado transacional no Git não escala e não reflete como um pipeline real se comporta.

### Variável `data_raw_path` em vez de caminho fixo

O caminho da pasta de dados brutos é parametrizado (`vars.data_raw_path` no `dbt_project.yml`), permitindo apontar para pastas diferentes conforme o ambiente (local, CI) sem editar o `sources.yml`.

## Modelagem dimensional

| Camada | Modelo | Grão | Observação |
|---|---|---|---|
| **staging** | `stg_olist__*` | Espelha a fonte | Limpeza e cast de tipos, sem lógica de negócio |
| **intermediate** | `int_order_payments_pivoted` | 1 linha por pedido | Pivota valores por forma de pagamento |
| **intermediate** | `int_geolocation_by_zip` | 1 linha por CEP | Resolve duplicação de ~53 linhas por CEP na fonte |
| **marts** | `dim_customers` | 1 linha por cliente | Enriquecida com coordenadas e nome do estado via `int_geolocation_by_zip` |
| **marts** | `dim_products` | 1 linha por produto | Categoria traduzida do português para o inglês |
| **marts** | `fct_orders` | 1 linha por item de pedido | Ver nota de grão abaixo |

### Nota de grão: por que `int_order_payments_pivoted` não é juntado em `fct_orders`

`int_order_payments_pivoted` está no grão de pedido. `fct_orders` está no grão de item de pedido — necessário para que `product_key` faça sentido na fact. Juntar os dois causaria fan-out: um pedido com 3 itens repetiria o mesmo valor de pagamento em 3 linhas, e qualquer `SUM()` posterior inflaria o resultado em 3×, um erro silencioso, sem gerar nenhum aviso. A tabela de pagamentos pivotados fica disponível separadamente, para análises no grão de pedido.

### Nota sobre `int_geolocation_by_zip`

A tabela de geolocalização tem, em média, ~53 linhas por CEP (1.000.163 linhas para 19.015 CEPs distintos). Resolvido via `AVG()` das coordenadas e `MAX()` para cidade e estado — uma escolha determinística, não estatisticamente a mais correta. Uma melhoria futura seria usar `MODE()` para pegar o valor mais frequente.

42 linhas (~0,0042% do total) tinham coordenadas fora do intervalo geográfico do Brasil, filtradas antes da agregação, dado o volume irrisório.

## Macros customizadas

- **`pad_zip_code`**: padroniza CEP como texto de 5 dígitos, evitando perda do zero à esquerda que ocorreria com inferência de tipo inteiro.
- **`pivot_sum`**: gera dinamicamente `SUM(CASE WHEN ...)` para uma lista de valores, eliminando repetição manual do pivot de formas de pagamento.
- **`is_valid_brazil_coordinates`**: retorna a condição booleana de latitude e longitude dentro dos limites do Brasil, reutilizável, com limites configuráveis via argumento.

## Testes de qualidade implementados

- **Genéricos do dbt**: `unique`, `not_null`, `accepted_values`, `relationships`.
- **`dbt_utils.accepted_range`** para valores monetários não negativos.
- **`dbt_utils.unique_combination_of_columns`** para chaves compostas:
  - `order_id` + `order_item_id`;
  - `order_id` + `payment_sequential`;
  - `review_id` + `order_id`.
- **Teste singular `assert_payments_pivot_reconciles.sql`**: valida que a soma de pagamentos não se perde no pivot da camada intermediate.
- **`relationships` em `fct_orders`**: garante que toda linha da fact tem uma dimensão correspondente, sem chaves órfãs.

## CI/CD com GitHub Actions

A cada push ou Pull Request na branch `main`, o workflow `.github/workflows/dbt-ci.yml` sobe uma VM Ubuntu limpa, instala Python e as dependências do `requirements.txt`, e roda `dbt deps`, `dbt seed` e `dbt build` (models e testes).

Como os dados brutos completos não são versionados, o CI roda sobre uma amostra relacional — na pasta `data_raw_sample` —, um subconjunto de pedidos e todas as entidades relacionadas a eles (clientes, itens, produtos, vendedores, pagamentos, reviews), preservando a integridade referencial entre as tabelas. A amostra foi gerada via consulta SQL sobre o warehouse completo, não por corte isolado de cada arquivo, já que um corte independente por arquivo quebraria os relacionamentos entre `order_id`, `customer_id` e `product_id`, fazendo os testes `relationships` falharem por amostragem — não por erro real de modelagem.

## Estrutura de pastas

```
ecommerce-analytics-olist/
├── .github/workflows/dbt-ci.yml   # CI que roda dbt deps, seed e build
├── data_raw/                      # CSVs brutos do Kaggle (não versionado)
├── data_raw_sample/               # Amostra relacional usada pelo CI
└── dbt_project/
    ├── dbt_project.yml
    ├── profiles.yml               # Commitado porque DuckDB não usa credenciais
    ├── packages.yml               # Inclui dbt_utils
    ├── seeds/                     # Tabelas de referência pequenas e estáticas
    ├── macros/
    │   ├── generate_schema_name.sql   # Schemas sem concatenação com o default
    │   ├── pad_zip_code.sql
    │   ├── pivot_sum.sql
    │   └── is_valid_brazil_coordinates.sql
    ├── models/
    │   ├── staging/               # Sources externas e limpeza 1:1 com a fonte
    │   ├── intermediate/          # Lógica de negócio: pivot e deduplicação
    │   └── marts/                 # Star schema com dim_ e fct_
    ├── tests/                     # Teste singular de reconciliação
    └── requirements.txt
```

## Como rodar localmente

1. Criar e ativar o ambiente virtual; instalar as dependências com `pip install -r requirements.txt`.
2. Entrar na pasta `dbt_project` e rodar, em sequência:

```bash
dbt deps  --profiles-dir .
dbt seed  --profiles-dir .
dbt build --profiles-dir .
```

3. Para documentação e lineage:

```bash
dbt docs generate --profiles-dir .
dbt docs serve    --profiles-dir .
```

> [!IMPORTANT]
> Os CSVs completos precisam ser baixados do Kaggle (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) e colocados em `data_raw/`, com os nomes originais (`olist_customers_dataset.csv`, `olist_orders_dataset.csv`, e assim por diante).

## Decisões de projeto registradas para revisão técnica

- **Sources externas vs. seeds**: dado transacional não é versionado; só tabelas de referência pequenas viram seed.
- **Grão da fact**: `fct_orders` no grão de item de pedido, não de pedido — decisão que evita perder a granularidade de produto, ao custo de não incorporar diretamente os dados de pagamento.
- **Deduplicação de geolocalização**: `MAX()` para texto (determinístico, mas não necessariamente o mais correto estatisticamente) e `AVG()` para coordenadas.
- **Amostra de CI construída via relação**, não por corte isolado por arquivo, para preservar integridade referencial nos testes.

## Próximos passos possíveis

- Trocar `data_raw` local por leitura direta de um bucket S3 ou GCS — a extensão `httpfs` do DuckDB, já habilitada no `profiles.yml`, torna essa troca direta.
- Reintroduzir uma camada de consumo ou visualização, se necessário no futuro.
