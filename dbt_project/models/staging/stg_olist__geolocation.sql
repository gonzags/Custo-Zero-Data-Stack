with source as (

    select * from {{ source('olist_raw', 'geolocation') }}

),

renamed as (

    select
        {{ pad_zip_code('geolocation_zip_code_prefix') }} as geolocation_zip_code_prefix,
        cast(geolocation_lat as double)                            as geolocation_latitude,
        cast(geolocation_lng as double)                            as geolocation_longitude,
        lower(trim(geolocation_city))                              as geolocation_city,
        upper(trim(geolocation_state))                             as geolocation_state

    from source

)

select * from renamed
