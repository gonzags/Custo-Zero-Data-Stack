{% macro pivot_sum(column_name, values, amount_column, suffix='_value', else_value=0) %}
    {%- for v in values %}
        sum(case when {{column_name}} = '{{v}}' then {{amount_column}} else {{else_value}} end) as {{v}}{{suffix}}
        {%- if not loop.last %},{% endif %}
    {%- endfor %}
{% endmacro %}
