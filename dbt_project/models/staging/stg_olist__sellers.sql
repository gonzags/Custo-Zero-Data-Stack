with source as (

    select * from {{ source('olist_raw', 'sellers') }}

),

renamed as (

    select
        seller_id,
        -- CEP como texto de 5 dígitos: o DuckDB infere inteiro e perderia o zero
        -- à esquerda (01046 viraria 1046), o que quebraria joins futuros.
        lpad(cast(seller_zip_code_prefix as varchar), 5, '0') as seller_zip_code_prefix,
        lower(trim(seller_city))                              as seller_city,
        upper(trim(seller_state))                             as seller_state

    from source

)

select * from renamed
