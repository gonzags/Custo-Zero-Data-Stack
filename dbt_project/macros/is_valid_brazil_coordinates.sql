{% macro is_valid_brazil_coordinates(lat_column, lng_column, lat_min=-34, lat_max=6, lng_min=-74, lng_max=-34) %}
    {{ lat_column }} between {{ lat_min }} and {{ lat_max }}
    and {{ lng_column }} between {{ lng_min }} and {{ lng_max }}
{% endmacro %}