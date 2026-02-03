# Snowflake SchemaChange CI/CD (GitHub Actions) — DEV / UAT / PROD

This repo uses **schemachange** (Python-based migrations) to apply versioned Snowflake SQL changes via **GitHub Actions**, with **DEV/UAT/PROD** controlled by **GitHub Environments** and Snowflake **key-pair authentication**.

---

## 1) What you get

- ✅ Versioned migrations (`V__*.sql`) applied **once** in order
- ✅ Repeatable migrations (`R__*.sql`) reapplied every deploy (ideal for views/procs)
- ✅ DEV/UAT/PROD promotion via branches:
  - `develop` → DEV
  - `release/*` → UAT
  - `main` → PROD (can require approvals)
- ✅ Security migrations (roles & grants) included

---

## 2) Repo structure
```bash
├─ migrations/
│ ├─ 00_security/
│ │ ├─ V1.0.0__create_roles.sql
│ │ └─ V1.0.1__grant_privileges.sql
│ ├─ 10_schemas/
│ │ └─ V1.1.0__init_schemas.sql
│ ├─ 20_tables/
│ │ ├─ V1.2.0__create_core_tables.sql
│ │ └─ V1.2.1__add_columns.sql
│ └─ 90_views/
│ └─ R__repeatable_views.sql
├─ schemachange-config.yml
└─ .github/
  └─ workflows/
    ├─ schemachange_pr.yml
    └─ schemachange_deploy.yml
```
---

## 3) Prerequisites

### 3.1 Snowflake
You need:
- A **CI user** (e.g., `CICD_USER`)
- A **CI role** per environment (recommended):
  - `CICD_DEV_ROLE`, `CICD_UAT_ROLE`, `CICD_PROD_ROLE`
- A warehouse per env (or shared): `CI_WH`
- A database per env:
  - `ANALYTICS_DEV`, `ANALYTICS_UAT`, `ANALYTICS_PROD`

> If your governance does NOT allow CI to create roles/grants, see section **9** for options.

### 3.2 GitHub
You need:
- GitHub repo with Actions enabled
- GitHub Environments created: `dev`, `uat`, `prod`

---

## 4) Snowflake key-pair authentication (recommended for CI)

### 4.1 Generate keys locally
Run on your machine:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

### 4.2 Attach public key to the Snowflake user

Copy the contents of rsa_key.pub and run in Snowflake:
```sql
ALTER USER CICD_USER SET RSA_PUBLIC_KEY='-----BEGIN PUBLIC KEY-----...-----END PUBLIC KEY-----';
```

## 5) Create GitHub Environments + Secrets

Create 3 environments in GitHub:

- dev
- uat
- prod

For each environment, add these secrets:

- SNOWFLAKE_ACCOUNT 
  - Example: xy12345.ap-southeast-1

- SNOWFLAKE_USER 
  - Example: CICD_USER

- SNOWFLAKE_ROLE 
  - Example: CICD_DEV_ROLE (in dev), CICD_UAT_ROLE (in uat), CICD_PROD_ROLE (in prod)

- SNOWFLAKE_WAREHOUSE 
  - Example: CI_WH

- SNOWFLAKE_DATABASE 
  - Example: ANALYTICS_DEV (dev), ANALYTICS_UAT (uat), ANALYTICS_PROD (prod)

- SNOWFLAKE_SCHEMA 
  - This is the schema that stores the schemachange history table
    - Example: SCHEMA_CHANGE

- SNOWFLAKE_PRIVATE_KEY_P8 
  - Paste the entire contents of rsa_key.p8

**(Recommended) Protect PROD**

In GitHub → Environments → prod:

- Enable Required reviewers so production deploy requires approval.

## 6) schemachange configuration

Create schemachange-config.yml at repo root:

```yaml
config-version: 1
root-folder: migrations

# schemachange writes which migrations ran here:
change-history-table: SCHEMA_CHANGE.CHANGE_HISTORY

# default vars (overridden in CI)
vars:
  env: "DEV"
  db_name: "ANALYTICS_DEV"
  core_schema: "CORE"
  views_schema: "VIEWS"
```

## 7) Migration files (copy-paste examples)

### 7.1 migrations/00_security/V1.0.0__create_roles.sql

```sql
-- Create environment-specific roles (DEV/UAT/PROD)
CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_ADMIN;
CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_RW;
CREATE ROLE IF NOT EXISTS ANALYTICS_{{ env }}_RO;

-- Role hierarchy
GRANT ROLE ANALYTICS_{{ env }}_RO TO ROLE ANALYTICS_{{ env }}_RW;
GRANT ROLE ANALYTICS_{{ env }}_RW TO ROLE ANALYTICS_{{ env }}_ADMIN;

```

### 7.2 migrations/00_security/V1.0.1__grant_privileges.sql
```sql
USE DATABASE {{ db_name }};

CREATE SCHEMA IF NOT EXISTS {{ core_schema }};
CREATE SCHEMA IF NOT EXISTS {{ views_schema }};
CREATE SCHEMA IF NOT EXISTS SCHEMA_CHANGE;

-- USAGE
GRANT USAGE ON DATABASE {{ db_name }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT USAGE ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT USAGE ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

-- READ access
GRANT SELECT ON ALL TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

GRANT SELECT ON ALL VIEWS IN SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RO;

-- WRITE / DDL access (tune for your governance)
GRANT CREATE TABLE ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;
GRANT CREATE VIEW  ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_RW;

GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_RW;

-- ADMIN bounded control
GRANT ALL PRIVILEGES ON SCHEMA {{ core_schema }} TO ROLE ANALYTICS_{{ env }}_ADMIN;
GRANT ALL PRIVILEGES ON SCHEMA {{ views_schema }} TO ROLE ANALYTICS_{{ env }}_ADMIN;
```

### 7.3 migrations/10_schemas/V1.1.0__init_schemas.sql

```sql
USE DATABASE {{ db_name }};
CREATE SCHEMA IF NOT EXISTS {{ core_schema }};
CREATE SCHEMA IF NOT EXISTS {{ views_schema }};
CREATE SCHEMA IF NOT EXISTS SCHEMA_CHANGE;
```

### 7.4 migrations/20_tables/V1.2.0__create_core_tables.sql

```sql
USE DATABASE {{ db_name }};
USE SCHEMA {{ core_schema }};

CREATE TABLE IF NOT EXISTS DIM_CUSTOMER (
  CUSTOMER_ID   VARCHAR NOT NULL,
  CUSTOMER_NAME VARCHAR,
  EMAIL         VARCHAR,
  CREATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP,
  UPDATED_AT    TIMESTAMP_NTZ,
  PRIMARY KEY (CUSTOMER_ID)
);

CREATE TABLE IF NOT EXISTS FACT_ORDERS (
  ORDER_ID      VARCHAR NOT NULL,
  CUSTOMER_ID   VARCHAR NOT NULL,
  ORDER_DATE    DATE,
  ORDER_AMOUNT  NUMBER(12,2),
  CREATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ORDER_ID)
);
```
### 7.5 migrations/20_tables/V1.2.1__add_columns.sql
```sql
USE DATABASE {{ db_name }};
USE SCHEMA {{ core_schema }};

ALTER TABLE DIM_CUSTOMER
ADD COLUMN IF NOT EXISTS CUSTOMER_SEGMENT VARCHAR;

ALTER TABLE FACT_ORDERS
ADD COLUMN IF NOT EXISTS ORDER_STATUS VARCHAR;
```

### 7.6 migrations/90_views/R__repeatable_views.sql
```sql
USE DATABASE {{ db_name }};
USE SCHEMA {{ views_schema }};

CREATE OR REPLACE VIEW VW_ORDER_SUMMARY AS
SELECT
  o.ORDER_ID,
  o.ORDER_DATE,
  o.ORDER_AMOUNT,
  o.ORDER_STATUS,
  c.CUSTOMER_NAME,
  c.CUSTOMER_SEGMENT
FROM {{ db_name }}.{{ core_schema }}.FACT_ORDERS o
JOIN {{ db_name }}.{{ core_schema }}.DIM_CUSTOMER c
  ON o.CUSTOMER_ID = c.CUSTOMER_ID;
```
## 8) GitHub Actions workflows
### 8.1 PR validation (dry-run)

Create .github/workflows/schemachange_pr.yml:
```sql
name: schemachange - PR validate

on:
  pull_request:
    branches: [ "main", "develop" ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install deps
        run: |
          pip install schemachange snowflake-connector-python

      - name: Dry run (DEV vars by default)
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_ROLE: ${{ secrets.SNOWFLAKE_ROLE }}
          SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}
          SNOWFLAKE_DATABASE: ${{ secrets.SNOWFLAKE_DATABASE }}
          SNOWFLAKE_SCHEMA: ${{ secrets.SNOWFLAKE_SCHEMA }}
          SNOWFLAKE_PRIVATE_KEY_P8: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_P8 }}
        run: |
          python - << 'PY'
          import os, tempfile
          key = os.environ["SNOWFLAKE_PRIVATE_KEY_P8"]
          f = tempfile.NamedTemporaryFile(delete=False, mode="w")
          f.write(key)
          f.close()
          print(f.name)
          PY

          schemachange \
            -f migrations \
            -a "$SNOWFLAKE_ACCOUNT" \
            -u "$SNOWFLAKE_USER" \
            -r "$SNOWFLAKE_ROLE" \
            -w "$SNOWFLAKE_WAREHOUSE" \
            -d "$SNOWFLAKE_DATABASE" \
            -c "$SNOWFLAKE_SCHEMA" \
            --config-file schemachange-config.yml \
            --create-change-history-table \
            --dry-run \
            --vars "env=DEV" \
            --vars "db_name=$SNOWFLAKE_DATABASE" \
            --vars "core_schema=CORE" \
            --vars "views_schema=VIEWS"
```
### 8.2 Deploy (DEV/UAT/PROD based on branch)
Create .github/workflows/schemachange_deploy.yml:

```sql
name: schemachange - deploy

on:
  push:
    branches:
      - develop
      - main
      - "release/**"

jobs:
  deploy:
    runs-on: ubuntu-latest

    # Branch -> GitHub Environment
    environment: ${{ 
      github.ref_name == 'main' && 'prod' ||
      startsWith(github.ref_name, 'release/') && 'uat' ||
      'dev'
    }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install deps
        run: |
          pip install schemachange snowflake-connector-python

      - name: Deploy migrations
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_ROLE: ${{ secrets.SNOWFLAKE_ROLE }}
          SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}
          SNOWFLAKE_DATABASE: ${{ secrets.SNOWFLAKE_DATABASE }}
          SNOWFLAKE_SCHEMA: ${{ secrets.SNOWFLAKE_SCHEMA }}
          SNOWFLAKE_PRIVATE_KEY_P8: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_P8 }}
        run: |
          python - << 'PY'
          import os, tempfile
          key = os.environ["SNOWFLAKE_PRIVATE_KEY_P8"]
          f = tempfile.NamedTemporaryFile(delete=False, mode="w")
          f.write(key)
          f.close()
          print(f.name)
          PY

          # Use environment name (dev/uat/prod) to construct vars
          # We pass env in upper-case for role naming convention (DEV/UAT/PROD).
          ENV_UPPER=$(echo "${{ job.environment }}" | tr '[:lower:]' '[:upper:]')

          schemachange \
            -f migrations \
            -a "$SNOWFLAKE_ACCOUNT" \
            -u "$SNOWFLAKE_USER" \
            -r "$SNOWFLAKE_ROLE" \
            -w "$SNOWFLAKE_WAREHOUSE" \
            -d "$SNOWFLAKE_DATABASE" \
            -c "$SNOWFLAKE_SCHEMA" \
            --config-file schemachange-config.yml \
            --create-change-history-table \
            --vars "env=$ENV_UPPER" \
            --vars "db_name=$SNOWFLAKE_DATABASE" \
            --vars "core_schema=CORE" \
            --vars "views_schema=VIEWS"
```
## 9) Security governance options
### Split “security pipeline” (recommended in strict orgs)

- Only run migrations/00_security/* via manual approval:
    -   GitHub Actions workflow_dispatch 
    - protected environment (prod approvals)
- Regular CI deploy runs only schemas/tables/views

## 10) Run locally (developer machine)
### 10.1 Install
```bash
python -m venv .venv
source .venv/bin/activate
pip install schemachange snowflake-connector-python
```
### 10.2 Export env vars
```bash
export SNOWFLAKE_ACCOUNT="xy12345.ap-southeast-1"
export SNOWFLAKE_USER="CICD_USER"
export SNOWFLAKE_ROLE="CICD_DEV_ROLE"
export SNOWFLAKE_WAREHOUSE="CI_WH"
export SNOWFLAKE_DATABASE="ANALYTICS_DEV"
export SNOWFLAKE_SCHEMA="SCHEMA_CHANGE"

# Put your private key in a file path you control:
export SNOWFLAKE_PRIVATE_KEY_PATH="$HOME/.keys/rsa_key.p8"
```
### 10.3 Run schemachange
```bash
schemachange \
  -f migrations \
  -a "$SNOWFLAKE_ACCOUNT" \
  -u "$SNOWFLAKE_USER" \
  -r "$SNOWFLAKE_ROLE" \
  -w "$SNOWFLAKE_WAREHOUSE" \
  -d "$SNOWFLAKE_DATABASE" \
  -c "$SNOWFLAKE_SCHEMA" \
  --config-file schemachange-config.yml \
  --create-change-history-table \
  --vars "env=DEV" \
  --vars "db_name=$SNOWFLAKE_DATABASE" \
  --vars "core_schema=CORE" \
  --vars "views_schema=VIEWS"
```
### 10.4 Dry run
```bash
schemachange \
  -f migrations \
  -a "$SNOWFLAKE_ACCOUNT" \
  -u "$SNOWFLAKE_USER" \
  -r "$SNOWFLAKE_ROLE" \
  -w "$SNOWFLAKE_WAREHOUSE" \
  -d "$SNOWFLAKE_DATABASE" \
  -c "$SNOWFLAKE_SCHEMA" \
  --config-file schemachange-config.yml \
  --create-change-history-table \
  --dry-run \
  --vars "env=DEV" \
  --vars "db_name=$SNOWFLAKE_DATABASE" \
  --vars "core_schema=CORE" \
  --vars "views_schema=VIEWS"
```

## 11) Operational tips

- Keep versioned migrations strictly additive and one-way. 
- Put views/procs/functions in repeatables (R__). 
- Use ON FUTURE TABLES/VIEWS grants to avoid constant grant churn. 
- Use GitHub prod environment approvals for governance. 
- Keep change-history table in SCHEMA_CHANGE.CHANGE_HISTORY to avoid cluttering CORE/VIEWS.

## 12) Quick checklist

 - Keys created and public key attached to Snowflake user 
 - GitHub Environments created: dev/uat/prod 
 - Environment secrets set correctly (account, role, db, key)
 - schemachange-config.yml present 
 - Migrations in correct order and naming 
 - Workflows committed under .github/workflows/




