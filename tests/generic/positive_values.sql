{% test positive_values(model, column_name) %}

    select
        {{ column_name }},
        count(*) as failures
    from {{ model }}
    where {{ column_name }} < 0
    having count(*) > 0

{% endtest %}