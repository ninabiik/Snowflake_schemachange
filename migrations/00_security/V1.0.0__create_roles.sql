-- V1.0.0__create_roles.sql
-- Create roles for analytics access tiers

-- Use vars so each environment gets its own roles
-- Example output: ANALYTICS_DEV_ADMIN, ANALYTICS_DEV_RW, ANALYTICS_DEV_RO

CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_ADMIN;
CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_RW;
CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_RO;

-- Optional: define hierarchy (ADMIN inherits RW inherits RO)
GRANT ROLE ANALYTICS_{{ env }}_RO TO ROLE ANALYTICS_{{ env }}_RW;
GRANT ROLE ANALYTICS_{{ env }}_RW TO ROLE ANALYTICS_{{ env }}_ADMIN;
