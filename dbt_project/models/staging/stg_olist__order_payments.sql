with source as (

    select * from {{ source('olist_raw', 'order_payments') }}

),

renamed as (

    select
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        cast(payment_value as decimal(12, 2)) as payment_value

    from source

)

select * from renamed
