with customers as (

    select * from {{ ref('stg_olist__customers') }}

),

geolocation as (

    select * from {{ ref('int_geolocation_by_zip') }}

),

joined as (

    select
        {{ dbt_utils.generate_surrogate_key(['customers.customer_id']) }} as customer_key,
        customers.customer_id,
        customers.customer_unique_id,
        customers.customer_zip_code_prefix,
        case when
            customers.customer_state = geolocation.geolocation_state
            then geolocation.state_name
            else customers.customer_city
        end as customer_city,
        customers.customer_state,
        geolocation.state_name         as customer_state_name,
        geolocation.geolocation_latitude,
        geolocation.geolocation_longitude

    from customers
    left join geolocation
        on customers.customer_zip_code_prefix = geolocation.geolocation_zip_code_prefix

)

select * from joined