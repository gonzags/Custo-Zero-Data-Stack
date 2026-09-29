{%- macro pad_zip_code(column_name) -%}
    lpad(cast( {{column_name}} as varchar), 5, '0')
{%- endmacro -%}
