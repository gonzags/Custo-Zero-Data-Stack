with order_items as (

    select * from {{ ref('stg_olist__order_items') }}

),

orders as (

    select * from {{ ref('stg_olist__orders') }}

),

joined as (

    select
        {{ dbt_utils.generate_surrogate_key(
            ['order_items.order_id', 'order_items.order_item_id']
        ) }}                                                          as order_item_key,
        order_items.order_id,
        order_items.order_item_id,

        {{ dbt_utils.generate_surrogate_key(['orders.customer_id']) }} as customer_key,
        {{ dbt_utils.generate_surrogate_key(['order_items.product_id']) }} as product_key,

        orders.order_status,
        orders.order_purchased_at,
        orders.order_delivered_customer_at,
        orders.order_estimated_delivery_at,

        order_items.item_price,
        order_items.item_freight_value,
        order_items.item_price + order_items.item_freight_value as item_total_value

    from order_items
    left join orders
        on order_items.order_id = orders.order_id

)

select * from joined