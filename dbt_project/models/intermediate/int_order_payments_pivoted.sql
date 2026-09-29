{% set payment_types = ['credit_card', 'boleto', 'voucher', 'debit_card', 'not_defined'] %}

select
    order_id,
    {{ pivot_sum('payment_type', payment_types, 'payment_value') }},
    sum(payment_value) as total_payment_value,
    count(distinct payment_type) as distinct_payment_types_used
from {{ ref('stg_olist__order_payments') }}
group by order_id
