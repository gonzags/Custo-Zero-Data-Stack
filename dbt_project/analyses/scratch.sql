select
    geolocation_zip_code_prefix,
    case
        when {{ is_valid_brazil_coordinates('geolocation_latitude', 'geolocation_longitude') }}
        then {{'geolocation_latitude'}} || ', ' || {{'geolocation_longitude'}}
        else 'Falso'
    end as brazil_coordinates,
    b.state_name,
    a.geolocation_state
    
from {{ ref('stg_olist__geolocation') }} a
join {{ ref('geolocation_state_pattern') }} b
    on a.geolocation_state = b.uf


