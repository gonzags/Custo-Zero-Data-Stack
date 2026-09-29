-- Teste singular: falha se a soma total de pagamentos na intermediate
-- divergir da soma na staging (sinal de erro no group by do pivot).
-- Um teste dbt passa quando a query abaixo retorna ZERO linhas.

with staging_totals as (
    select
        order_id,
        round(sum(payment_value), 2) as staging_total
    from {{ ref('stg_olist__order_payments') }}
    group by order_id
),

intermediate_totals as (
    select
        order_id,
        round(total_payment_value, 2) as intermediate_total
    from {{ ref('int_order_payments_pivoted') }}
)

select
    staging_totals.order_id,
    staging_totals.staging_total,
    intermediate_totals.intermediate_total
from staging_totals
join intermediate_totals
    on staging_totals.order_id = intermediate_totals.order_id
where staging_totals.staging_total != intermediate_totals.intermediate_total
