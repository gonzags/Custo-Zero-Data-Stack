with source as (

    select * from {{ source('olist_raw', 'geolocation') }}

),

renamed as (

    select
        lpad(cast(geolocation_zip_code_prefix as varchar), 5, '0') as geolocation_zip_code_prefix,
        cast(geolocation_lat as double)                            as geolocation_latitude,
        cast(geolocation_lng as double)                            as geolocation_longitude,
        lower(trim(geolocation_city))                              as geolocation_city,
        upper(trim(geolocation_state))                             as geolocation_state

    from source

)

-- Atenção: esta tabela tem VÁRIAS linhas por CEP. Não resolva isso aqui.
-- A agregação por CEP (média das coordenadas, por exemplo) vai para um modelo
-- intermediate, antes de qualquer join com customers ou sellers.
select * from renamed
