-- macros/grant_privileges.sql
-- Runs AFTER every model build to grant SELECT to reporting role.
-- This also documents the permissions needed to fix the error seen in dbt Cloud.

{% macro grant_select(role='REPORTER') %}
  GRANT SELECT ON {{ this }} TO ROLE {{ role }};
{% endmacro %}


-- ─── on-run-end hook (add to dbt_project.yml) ────────────────────────────────
-- on-run-end:
--   - "{{ grant_select(role='REPORTER') }}"
-- ─────────────────────────────────────────────────────────────────────────────


{% macro generate_schema_name(custom_schema_name, node) -%}
  {#
    Override the default schema generation so that:
      - In prod  → schema is exactly the custom_schema (bronze / silver / gold)
      - In dev   → schema is <target_schema>_<custom_schema>
                   e.g. DBT_SGAUTAM_bronze

    This prevents the dev role from needing CREATE on the shared schemas.
  #}

  {%- set default_schema = target.schema -%}

  {%- if custom_schema_name is none -%}
    {{ default_schema }}

  {%- elif target.name == 'prod' -%}
    {{ custom_schema_name | trim }}

  {%- else -%}
    {{ default_schema }}_{{ custom_schema_name | trim }}

  {%- endif -%}
{%- endmacro %}
