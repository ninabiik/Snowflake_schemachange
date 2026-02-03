-- R__repeatable_views.sql
USE DATABASE {{ db_name }};
USE SCHEMA {{ views_schema }};

CREATE OR REPLACE VIEW VW_ORDER_SUMMARY AS
SELECT
  o.ORDER_ID,
  o.ORDER_DATE,
  o.ORDER_AMOUNT,
  c.CUSTOMER_NAME
FROM {{ db_name }}.{{ core_schema }}.FACT_ORDERS o
JOIN {{ db_name }}.{{ core_schema }}.DIM_CUSTOMER c
  ON o.CUSTOMER_ID = c.CUSTOMER_ID;
