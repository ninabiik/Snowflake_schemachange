-- V1.0.1__grant_privileges.sql
-- Grant usage + privileges for the environment DB/schemas

-- Switch to the environment database
USE DATABASE {{ db_name }};

-- Ensure schemas exist (safe if already created elsewhere)
CREATE SCHEMA IF NOT EXISTS {{ core_schema }};
CREATE SCHEMA IF NOT EXISTS {{ views_schema }};
CREATE SCHEMA IF NOT EXISTS SCHEMA_CHANGE;

-- Basic USAGE
GRANT USAGE ON DATABASE {{ db_name }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT USAGE ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT USAGE ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

-- RO: can read tables/views
GRANT SELECT ON ALL TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

GRANT SELECT ON ALL VIEWS IN SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

-- RW: can create/modify in CORE (adjust as needed)
GRANT USAGE ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;
GRANT CREATE TABLE ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;
GRANT CREATE VIEW ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RW;

-- Optional: if RW should be able to write data
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;

-- ADMIN: full control inside the DB (be careful; keep bounded)
GRANT ALL PRIVILEGES ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_ADMIN;
GRANT ALL PRIVILEGES ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_ADMIN;

-- Let ADMIN manage future grants by owning schemas (optional, org-dependent)
-- (Ownership patterns vary; only use if your governance allows it)
