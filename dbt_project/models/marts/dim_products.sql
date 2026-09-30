with products as (

    select * from {{ ref('stg_olist__products') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
    product_id,
    -- ajuste os nomes de coluna conforme o que você chamou na sua staging
    b.product_category_name_english as product_category_name,
    weight_g as product_weight_g,
    length_cm as product_length_cm,
    height_cm as product_height_cm,
    width_cm as product_width_cm

from products a
left join {{ ref('product_category_name_translation') }} b
    on a.category = b.product_category_name
 