with source as (

    select * from {{ source('olist_raw', 'products')}}

),

renamed as (

    select
        product_id,
        product_category_name as category,
        cast(product_name_lenght as INT) as name_length,
        cast(product_description_lenght as INT) as description_length,
        cast(product_photos_qty as INT) as photos_qty,
        cast(product_weight_g as INT) as weight_g,
        cast(product_length_cm as INT) as length_cm,
        cast(product_height_cm as INT) as height_cm,
        cast(product_width_cm as INT) as width_cm
    from source
)

select * from renamed
