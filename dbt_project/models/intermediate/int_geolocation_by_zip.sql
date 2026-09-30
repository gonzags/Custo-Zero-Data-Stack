with source as (

    select *
    from {{ ref('stg_olist__geolocation') }}
    where {{ is_valid_brazil_coordinates('geolocation_latitude', 'geolocation_longitude') }}

),

aggregated as (

    select
        geolocation_zip_code_prefix,
        avg(geolocation_latitude)  as geolocation_latitude,
        avg(geolocation_longitude) as geolocation_longitude,
        max(geolocation_city)      as geolocation_city,
        max(geolocation_state)     as geolocation_state

    from source
    group by geolocation_zip_code_prefix

)

select
    aggregated.geolocation_zip_code_prefix,
    aggregated.geolocation_latitude,
    aggregated.geolocation_longitude,
    aggregated.geolocation_state,
    state_names.state_name

from aggregated
left join {{ ref('geolocation_state_pattern') }} as state_names
    on aggregated.geolocation_state = state_names.uf