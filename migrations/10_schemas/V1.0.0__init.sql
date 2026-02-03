-- V1.1.0__init_schemas.sql
USE DATABASE {{ db_name }};

CREATE SCHEMA IF NOT EXISTS {{ core_schema }};
CREATE SCHEMA IF NOT EXISTS {{ views_schema }};
CREATE SCHEMA IF NOT EXISTS SCHEMA_CHANGE;