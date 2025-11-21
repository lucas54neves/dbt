# Airbnb Data Pipeline with dbt

A dbt project for transforming and modeling Airbnb data from [Inside Airbnb](https://insideairbnb.com/). This project processes raw Airbnb data stored in Snowflake and creates clean, analytics-ready models.

## Overview

This dbt project transforms raw Airbnb data into structured, queryable models. The data pipeline is integrated with Snowflake, where raw data is stored in the `AIRBNB.RAW` schema and transformed into clean source models.

## Data Source

The data used in this project comes from [Inside Airbnb](https://insideairbnb.com/), a mission-driven project that provides data and advocacy about Airbnb's impact on residential communities. The data is licensed under a Creative Commons Attribution 4.0 International License.

Inside Airbnb provides quarterly data for various cities and regions, including:
- **Listings data**: Detailed information about Airbnb listings
- **Calendar data**: Availability and pricing information
- **Reviews data**: Guest reviews and ratings
- **Neighbourhoods data**: Geographic boundaries and neighborhood information

## Project Structure

```
dbt/
├── airbnb/
│   ├── models/
│   │   ├── src/
│   │   │   ├── src_listings.sql
│   │   │   ├── src_hosts.sql
│   │   │   └── src_reviews.sql
│   │   ├── dim/
│   │   │   ├── dim_listings_cleansed.sql
│   │   │   ├── dim_hosts_cleansed.sql
│   │   │   └── dim_listings_w_hosts.sql
│   │   ├── fct/
│   │   │   └── fct_reviews.sql
│   │   ├── mart/
│   │   │   └── mart_fullmoon_reviews.sql
│   │   └── sources.yml
│   ├── snapshots/
│   │   ├── raw_listings_snapshot.yml
│   │   ├── raw_hosts_snapshot.yml
│   ├── seeds/
│   │   └── seed_full_moon_dates.csv
│   ├── dbt_project.yml
│   └── profiles.yml
└── README.md
```

## Models

### Source Models (`src/`)

The project includes three source models that clean and standardize the raw data:

#### `src_listings`
Transforms raw listings data into a clean format with standardized column names:
- `listing_id`: Unique identifier for each listing
- `listing_name`: Name of the listing
- `listing_url`: URL to the listing page
- `room_type`: Type of room (entire place, private room, etc.)
- `minimum_nights`: Minimum number of nights required
- `host_id`: Identifier for the host
- `price_str`: Price as a string (for further processing)
- `created_at`: Timestamp when the record was created
- `updated_at`: Timestamp when the record was last updated

#### `src_hosts`
Cleans and standardizes host information:
- `host_id`: Unique identifier for each host
- `host_name`: Name of the host
- `is_superhost`: Boolean indicating if the host is a superhost
- `created_at`: Timestamp when the record was created
- `updated_at`: Timestamp when the record was last updated

#### `src_reviews`
Transforms review data into an analytics-ready format:
- `listing_id`: Identifier linking to the listing
- `reviewer_name`: Name of the reviewer
- `review_date`: Date of the review
- `review_text`: Text content of the review
- `review_sentiment`: Sentiment analysis of the review

All source models now read from `sources.yml`, which maps Snowflake objects such as `AIRBNB.RAW.RAW_LISTINGS` to logical names (e.g., `source('airbnb', 'listings')`). This keeps warehouse details centralized and makes the source layer portable.

### Dimension Models (`dim/`)

#### `dim_listings_cleansed`
Standardizes listing-level attributes for downstream consumption:
- Cleans minimum-stay rules (`minimum_nights` defaults to 1 when 0)
- Strips the currency symbol from `price_str` and casts it to numeric
- Preserves host references and timestamps for slowly changing analysis

This model is materialized as a table (configured in `dbt_project.yml`) to simplify joins for downstream facts and marts.

#### `dim_hosts_cleansed`
Cleans and standardizes host information:
- Replaces NULL `host_name` values with 'Anonymous' for data quality
- Preserves `host_id`, `is_superhost` flag, and timestamps
- Provides clean host dimension for joining with listings

This model is materialized as a table to support efficient joins in downstream models.

#### `dim_listings_w_hosts`
Combines listing and host information into a single denormalized dimension:
- Joins `dim_listings_cleansed` with `dim_hosts_cleansed` on `host_id`
- Includes listing details (name, room type, price, minimum nights)
- Includes host details (name, superhost status)
- Uses `GREATEST(l.updated_at, h.updated_at)` to track the most recent update from either source

This model provides a comprehensive view of listings with their associated host information, ideal for analytics and reporting.

### Fact Models (`fct/`)

#### `fct_reviews`
- Incremental model that persists non-null guest reviews
- Filters out NULL `review_text` rows
- Uses `review_date` as the incremental key to append only new reviews
- Raises an error on schema changes to protect downstream marts

Run a full refresh (`dbt run --select fct_reviews --full-refresh`) if the schema or deduplication logic changes.

### Mart Models (`mart/`)

#### `mart_fullmoon_reviews`
Combines `fct_reviews` with a seed of full-moon dates to flag which guest stays happened the night after a full moon (`is_full_moon`). This model materializes as a table and is ideal for BI / dashboard consumption.

### Seeds (`seeds/`)

#### `seed_full_moon_dates.csv`
Calendar of historical and future full-moon dates used by the mart layer. Load or refresh the seed before running the mart so the lookup table is available:
```bash
cd airbnb
dbt seed --select seed_full_moon_dates
```

Seeds can be version-controlled like models, making the pipeline deterministic for derived datasets such as lunar calendars.

## Prerequisites

- dbt installed and configured
- Access to Snowflake with the following:
  - Database: `AIRBNB`
  - Schema: `RAW` (for raw data)
  - Appropriate permissions to read from raw tables and write to target schemas

## What is `profiles.yml`?

The `profiles.yml` file is a dbt configuration file that contains credentials and connection information for Snowflake (or another data warehouse). This file is essential for dbt to connect to your database and execute transformations.

### What is it used for?

The `profiles.yml` is used for:

1. **Authentication**: Stores the credentials needed to authenticate with Snowflake (username, password, or private key)
2. **Connection configuration**: Defines connection parameters such as account, warehouse, database, schema, and role
3. **Multiple environments**: Allows configuring different environments (dev, prod, staging) with different settings
4. **Security**: Keeps credentials local and out of version control

### Why is it not in Git?

The `profiles.yml` file is listed in `.gitignore` and **should not be committed to Git** because it contains sensitive information:

- Access credentials (passwords or private keys)
- Authentication information that could compromise database security
- Developer or environment-specific configurations

Each developer or environment should have their own `profiles.yml` file with their specific credentials.

### How to create `profiles.yml`?

Since the file is not versioned, you need to create it manually the first time you clone the repository. Follow these steps:

1. **Navigate to the project directory**:
   ```bash
   cd airbnb
   ```

2. **Create the `profiles.yml` file** in the `airbnb/` directory:
   ```bash
   touch profiles.yml
   ```

3. **Add the configuration** with your Snowflake credentials. Example structure:

   **Option 1: Password authentication**
   ```yaml
   airbnb:
     outputs:
       dev:
         type: snowflake
         account: <your-account-id>
         user: <your-username>
         password: <your-password>
         role: <your-role>
         database: AIRBNB
         schema: DEV
         warehouse: <your-warehouse>
         threads: 1
     target: dev
   ```

   **Option 2: Private key authentication (recommended for production)**
   ```yaml
   airbnb:
     outputs:
       dev:
         type: snowflake
         account: <your-account-id>
         user: <your-username>
         role: <your-role>
         private_key: "-----BEGIN ENCRYPTED PRIVATE KEY-----\n...\n-----END ENCRYPTED PRIVATE KEY-----\n"
         private_key_passphrase: <your-passphrase>
         database: AIRBNB
         schema: DEV
         warehouse: <your-warehouse>
         threads: 1
     target: dev
   ```

4. **Replace the values** between `< >` with your actual credentials:
   - `<your-account-id>`: Your Snowflake account ID (e.g., `pfglogg-ga39636`)
   - `<your-username>`: Username in Snowflake
   - `<your-password>`: User password (if using password authentication)
   - `<your-role>`: Snowflake role (e.g., `TRANSFORM`)
   - `<your-warehouse>`: Warehouse name (e.g., `COMPUTE_WH`)
   - `<your-passphrase>`: Passphrase to decrypt the private key (if using key authentication)

5. **Verify the connection**:
   ```bash
   dbt debug
   ```

   This command tests the connection and reports any configuration issues.

### File structure

- **`airbnb`**: Profile name (must match the project name defined in `dbt_project.yml`)
- **`outputs`**: Defines different output configurations (dev, prod, etc.)
- **`dev`**: Environment name (can be `dev`, `prod`, `staging`, etc.)
- **`target`**: Defines which environment to use by default

### Security tips

- **Never share** the contents of `profiles.yml` publicly
- **Use environment variables** for sensitive values when possible (with `env_var()` in dbt)
- **Use private key authentication** in production environments
- **Keep the file** only on your local machine

## Setup

1. **Install dbt** (if not already installed):
   ```bash
   pip install dbt-snowflake
   ```

2. **Configure your Snowflake connection** by creating the `airbnb/profiles.yml` file:
   
   Since `profiles.yml` is not versioned in Git (because it contains sensitive credentials), you need to create it manually. See the [What is `profiles.yml`?](#what-is-profilesyml) section above for detailed instructions on how to create and configure this file.

3. **Verify your connection**:
   ```bash
   cd airbnb
   dbt debug
   ```

## Usage

### Running Models

To run all models:
```bash
cd airbnb
dbt run
```

To run a specific model:
```bash
dbt run --select src_listings
```

To build a full end-to-end dataset (seed → sources → dims/facts/marts):
```bash
cd airbnb
dbt seed
dbt run --select src+ dim+ fct+ mart+
```

### Compiling Models

Use `dbt compile` to render the final SQL for your models without executing them in the warehouse. This is helpful for quickly validating Jinja logic, checking macro output, and catching broken references before spending time or credits running the models.
```bash
cd airbnb
dbt compile
```

### Full Refresh

The `--full-refresh` flag forces dbt to rebuild incremental models from scratch, ignoring the incremental logic and recreating the table completely.

**Normal execution** (`dbt run`):
- For incremental models (like `fct_reviews`), only processes new data
- On first run, creates the complete table
- On subsequent runs, adds only new records based on the incremental logic

**Full refresh** (`dbt run --full-refresh`):
- Deletes the existing table (if it exists)
- Recreates the table from scratch
- Processes all data again, not just new records
- The `{% if is_incremental() %}` condition evaluates to `False`

**When to use `--full-refresh`:**
- When the model logic has changed and you need to reprocess all data
- When there are data quality issues or duplicates
- When the table structure has changed
- To ensure data consistency after significant changes

**Examples:**
```bash
# Full refresh on a specific incremental model
dbt run --select fct_reviews --full-refresh

# Full refresh on all incremental models
dbt run --full-refresh

# Full refresh on all models in a directory
dbt run --select fct.* --full-refresh
```

### Testing

The `dbt test` command executes data quality tests defined in your project. Tests validate that your models meet expected data quality standards, ensuring reliability and correctness of your transformed data.

#### How It Works

The `dbt test` command works as follows:

1. **Test Discovery**: dbt automatically discovers all tests defined in your project, including:
   - **Generic tests**: Built-in tests like `unique`, `not_null`, `relationships`, `accepted_values`, `dbt_utils` tests
   - **Singular tests**: Custom SQL tests defined in `.sql` files in the `tests/` directory
   - **Schema tests**: Tests defined in `schema.yml` files (like in `airbnb/models/schema.yml`)

2. **Test Execution**: dbt compiles each test into SQL queries that check your data:
   - Tests return rows when they fail (e.g., `unique` test returns duplicate values)
   - Tests return no rows when they pass
   - Each test runs as a separate query against your data warehouse

3. **Results Reporting**: dbt reports the results of all tests:
   - Shows which tests passed and which failed
   - Displays the number of failing rows for each test
   - Provides error messages and details about failures

#### How to Use

To run all tests in your project:
```bash
cd airbnb
dbt test
```

To run tests on a specific model:
```bash
dbt test --select dim_listings_cleansed
```

To run tests on models in a directory:
```bash
dbt test --select dim.*
```

To run only generic tests (exclude singular tests):
```bash
dbt test --select test_type:generic
```

To run only singular tests:
```bash
dbt test --select test_type:singular
```

#### Why It's Useful

1. **Data Quality Assurance**: Tests validate that your data transformations produce correct and reliable results, catching errors before they affect downstream analyses or reports.

2. **Early Error Detection**: Running tests regularly helps identify data quality issues early in the pipeline, preventing bad data from propagating to downstream models.

3. **Documentation**: Tests serve as executable documentation, clearly defining the expected data quality standards for each model and column.

4. **CI/CD Integration**: Tests can be integrated into CI/CD pipelines to automatically validate data quality before deploying changes to production.

5. **Regression Prevention**: Tests help prevent regressions by catching issues when model logic changes or when source data quality degrades.

6. **Confidence in Data**: Passing tests give you confidence that your data is reliable and ready for use in analytics, reporting, and business decisions.

#### Example Tests in This Project

In `airbnb/models/schema.yml`, you'll find tests like:
- **`unique`**: Ensures `listing_id` is unique in `dim_listings_cleansed`
- **`not_null`**: Ensures `listing_id` and `host_id` are never null
- **`relationships`**: Validates that `host_id` in `dim_listings_cleansed` exists in `dim_hosts_cleansed`
- **`accepted_values`**: Ensures `room_type` only contains valid values

#### Test Severity: `severity: warn` vs `severity: error`

dbt allows you to configure the severity level for tests, which determines how test failures are handled. This is configured using the `severity` option in the test's `config` block.

**Default behavior** (no `severity` specified):
- Tests default to `severity: error`
- When a test fails, dbt treats it as an error
- The test run fails and stops execution (if using `dbt build` or `dbt test -x`)
- Pipeline execution is blocked until the test passes

**`severity: warn`**:
- When a test fails, dbt treats it as a warning instead of an error
- The test run continues even if the test fails
- Warnings are reported in the output but don't block pipeline execution
- Useful for monitoring data quality without blocking downstream processes
- Ideal for tests that check data volume, trends, or non-critical quality metrics

**`severity: error`** (explicit):
- Explicitly sets the test to fail on errors
- Same behavior as the default
- Use this when you want to be explicit about critical tests

**Example in this project:**

In `airbnb/models/schema.yml`, the `minimum_row_count` test on `dim_listings_cleansed` is configured with `severity: warn`:

```yaml
- name: dim_listings_cleansed
  data_tests:
    - minimum_row_count:
        arguments:
          min_row_count: 10000000
        config:
          severity: warn
```

This configuration means:
- If the table has fewer than 10,000,000 rows, dbt will emit a warning
- The pipeline will continue running even if the row count is below the threshold
- This allows monitoring data volume without blocking downstream processes
- Useful for detecting data loading issues or data volume anomalies without stopping the entire pipeline

**When to use `severity: warn`:**

1. **Data Volume Monitoring**: Tests that check if data volume meets expectations but shouldn't block the pipeline
2. **Non-Critical Quality Checks**: Tests for data quality issues that are important to know about but don't require immediate action
3. **Trend Monitoring**: Tests that track data trends over time where occasional failures are expected
4. **Informational Tests**: Tests that provide insights but aren't critical for data correctness

**When to use `severity: error` (default):**

1. **Data Integrity**: Tests that ensure data correctness (e.g., `unique`, `not_null`, `relationships`)
2. **Critical Business Rules**: Tests that validate critical business logic
3. **Referential Integrity**: Tests that ensure foreign key relationships are valid
4. **Data Type Validation**: Tests that ensure data types and formats are correct

**How to configure:**

```yaml
# Warning severity
- name: my_model
  columns:
    - name: my_column
      tests:
        - my_test:
            config:
              severity: warn

# Error severity (explicit)
- name: my_model
  columns:
    - name: my_column
      tests:
        - my_test:
            config:
              severity: error
```

**Viewing test results:**

When you run `dbt test`, warnings and errors are clearly distinguished in the output:

```
✓ PASS 1: unique test on dim_listings_cleansed.listing_id
⚠ WARN 2: minimum_row_count test on dim_listings_cleansed (below threshold)
✗ FAIL 3: not_null test on dim_listings_cleansed.host_id
```

Warnings are marked with `⚠ WARN` and errors with `✗ FAIL`.

#### Stop on First Failure: `dbt test -x`

The `-x` (or `--fail-fast`) flag makes dbt stop execution immediately when the first test fails, rather than continuing to run all remaining tests.

**Normal execution** (`dbt test`):
- Runs all tests in the project
- Continues even if some tests fail
- Reports all failures at the end
- Useful when you want to see the complete picture of all test failures

**Fail-fast execution** (`dbt test -x`):
- Stops immediately when the first test fails
- Does not run remaining tests
- Returns immediately with the first failure
- Useful for faster feedback during development

**When to use `dbt test -x`:**

1. **Development Workflow**: When iterating on models and you want immediate feedback on the first issue, rather than waiting for all tests to complete.

2. **CI/CD Pipelines**: In automated pipelines where you want to fail fast and save compute resources by not running unnecessary tests after a failure.

3. **Quick Validation**: When you want to quickly check if your changes broke something, without waiting for the full test suite.

4. **Debugging**: When fixing a specific issue and you want to focus on the first problem before addressing others.

**Examples:**
```bash
# Stop on first failure
dbt test -x

# Stop on first failure for a specific model
dbt test --select dim_listings_cleansed -x

# Stop on first failure for models in a directory
dbt test --select dim.* -x
```

**Comparison:**

**Normal execution** (`dbt test`):
```bash
$ dbt test
Running 10 tests...
✗ FAIL 1: unique test on dim_listings_cleansed.listing_id (2 failures)
✗ FAIL 2: not_null test on dim_listings_cleansed.host_id (5 failures)
✓ PASS 3: relationships test on dim_listings_cleansed.host_id
...
# Continues running all tests
```

**Fail-fast execution** (`dbt test -x`):
```bash
$ dbt test -x
Running 10 tests...
✗ FAIL 1: unique test on dim_listings_cleansed.listing_id (2 failures)
# Stops immediately, doesn't run remaining 9 tests
```

#### Debugging Tests

When a test fails, you need to understand why. dbt provides powerful debugging capabilities through compiled SQL files that show exactly what query is being executed.

##### How Test Debugging Works

When dbt runs tests, it compiles each test into a SQL query and stores it in the `target/compiled/` directory. These compiled SQL files are invaluable for debugging because they show:

1. **The exact SQL query** that the test executes
2. **The resolved references** (e.g., `ref('dim_listings_cleansed')` becomes the actual table name)
3. **The compiled Jinja logic** (if any macros or Jinja are used)
4. **The test logic** in its final, executable form

##### Where to Find Compiled Test Files

After running `dbt test` or `dbt compile`, compiled test files are located in:

```
airbnb/target/compiled/airbnb/models/schema.yml/
```

The file naming convention follows this pattern:
- Generic tests: `{test_name}_{model_name}_{column_name}_{hash}.sql`
- Example: `accepted_values_dim_listings_c_2a86f637e70df013556a8a127cb46aa1.sql`

**Note**: The `target/` directory is automatically created by dbt and is listed in `.gitignore` (it should not be committed to version control).

##### Step-by-Step Debugging Process

**1. Run the test to see the failure:**
```bash
cd airbnb
dbt test --select dim_listings_cleansed
```

**2. Compile tests to generate SQL files (without executing):**
```bash
dbt compile --select dim_listings_cleansed
```

This generates the compiled SQL files in `target/compiled/` without actually running the tests, which is useful for:
- Inspecting the SQL before execution
- Understanding complex test logic
- Preparing for debugging

**3. Locate the compiled test file:**
```bash
# List compiled test files
ls -la airbnb/target/compiled/airbnb/models/schema.yml/
```

**4. Examine the compiled SQL:**
Open the compiled SQL file to see exactly what query the test executes. For example, an `accepted_values` test might look like:

```sql
with all_values as (
    select
        room_type as value_field,
        count(*) as n_records
    from AIRBNB.DEV.dim_listings_cleansed
    group by room_type
)

select *
from all_values
where value_field not in (
    'Entire home/apt','Private room','Shared room','Hotel room'
)
```

**5. Execute the SQL manually in your data warehouse:**
Copy the SQL from the compiled file and run it directly in Snowflake (or your data warehouse). This allows you to:
- See the exact rows that are causing the test to fail
- Understand the data that violates the test condition
- Investigate why the data doesn't meet expectations

**6. Fix the issue:**
Based on what you find:
- **If the data is wrong**: Fix the source data or the model logic that produces it
- **If the test is wrong**: Adjust the test configuration in `schema.yml`
- **If the test logic needs refinement**: Modify the test or create a custom test

##### Example: Debugging a Failed `accepted_values` Test

**Scenario**: The `accepted_values` test on `room_type` fails.

**1. Run the test:**
```bash
$ dbt test --select dim_listings_cleansed
✗ FAIL accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values
  Got 1 result, configured to fail if != 0
```

**2. Compile to see the SQL:**
```bash
$ dbt compile --select dim_listings_cleansed
```

**3. Find and examine the compiled file:**
```bash
$ cat airbnb/target/compiled/airbnb/models/schema.yml/accepted_values_dim_listings_c_*.sql
```

**4. Run the SQL manually in Snowflake:**
```sql
-- Copy the SQL from the compiled file and run it
with all_values as (
    select
        room_type as value_field,
        count(*) as n_records
    from AIRBNB.DEV.dim_listings_cleansed
    group by room_type
)

select *
from all_values
where value_field not in (
    'Entire home/apt','Private room','Shared room','Hotel room'
)
```

**5. Analyze the results:**
The query returns rows showing which values are invalid:
```
value_field        | n_records
-------------------|----------
Hotel room, break  | 5
```

**6. Fix the issue:**
You discover that some records have `'Hotel room, break'` instead of `'Hotel room'`. You can either:
- Fix the data in the model: Update `dim_listings_cleansed.sql` to normalize this value
- Update the test: Add `'Hotel room, break'` to the accepted values list (if it's a valid value)

##### Why Compiled Files Are Useful

1. **Transparency**: See exactly what SQL is being executed, not just the test configuration
2. **Investigation**: Run the SQL manually to explore the data and understand failures
3. **Learning**: Understand how generic tests work by seeing their compiled SQL
4. **Customization**: Use the compiled SQL as a starting point for custom tests
5. **Performance**: Analyze query performance and optimize if needed
6. **Debugging Complex Logic**: When tests use macros or complex Jinja, the compiled file shows the final result

##### Tips for Effective Test Debugging

1. **Use `dbt compile` first**: Generate compiled files without executing tests to inspect the SQL
2. **Check the file structure**: Compiled files mirror your project structure, making them easy to locate
3. **Run SQL manually**: Execute the compiled SQL in your data warehouse to see actual failing rows
4. **Understand test logic**: Generic tests follow predictable patterns - learn them to debug faster
5. **Check dependencies**: If a test fails, ensure the underlying model is correct first
6. **Use `--select`**: Compile only specific tests to focus your debugging efforts
7. **Review test configuration**: Sometimes the test configuration in `schema.yml` needs adjustment, not the data

##### Common Test Patterns in Compiled SQL

- **`unique` test**: `SELECT column FROM model GROUP BY column HAVING COUNT(*) > 1`
- **`not_null` test**: `SELECT * FROM model WHERE column IS NULL`
- **`relationships` test**: `SELECT * FROM model WHERE foreign_key NOT IN (SELECT primary_key FROM referenced_model)`
- **`accepted_values` test**: `SELECT * FROM model WHERE column NOT IN (list_of_values)`

Understanding these patterns helps you quickly identify what a test is checking and why it might be failing.

#### Storing Test Failures in the Data Warehouse: `store_failures: true`

This project is configured to store test failures directly in the data warehouse, making debugging much easier and more efficient. This feature is enabled in `airbnb/dbt_project.yml`:

```yaml
data_tests:
  +store_failures: true
```

##### How It Works

When `store_failures: true` is enabled, dbt automatically creates tables in your data warehouse containing the actual rows that caused each test to fail. Instead of just seeing that a test failed, you can query these tables to see exactly which records violated the test condition.

**Normal behavior** (without `store_failures`):
- Tests run and report pass/fail status
- You only see the count of failing rows
- To see the actual failing data, you must manually run the compiled SQL

**With `store_failures: true`**:
- Tests run and report pass/fail status
- **Automatically creates tables** with the failing rows
- You can query these tables directly in your data warehouse
- Tables persist until the next test run (or until manually dropped)

##### Where Test Failures Are Stored

Test failure tables are created in the same schema as your models (configured in `profiles.yml`). For this project, that's typically `AIRBNB.DEV` (or your configured target schema).

**Table naming convention:**
```
dbt_test_failure_{test_name}
```

For example:
- `dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values`
- `dbt_test_failure_unique_dim_listings_cleansed_listing_id`
- `dbt_test_failure_not_null_dim_listings_cleansed_host_id`

##### How to Query Test Failures

After running `dbt test`, you can query the failure tables directly in Snowflake:

**1. List all test failure tables:**
```sql
-- In Snowflake, list all tables with the dbt_test_failure prefix
SHOW TABLES LIKE 'dbt_test_failure_%' IN SCHEMA AIRBNB.DEV;
```

**2. Query a specific test failure:**
```sql
-- Query failures from an accepted_values test
SELECT *
FROM AIRBNB.DEV.dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values;

-- Query failures from a unique test
SELECT *
FROM AIRBNB.DEV.dbt_test_failure_unique_dim_listings_cleansed_listing_id;

-- Query failures from a not_null test
SELECT *
FROM AIRBNB.DEV.dbt_test_failure_not_null_dim_listings_cleansed_host_id;
```

**3. Count failures:**
```sql
-- Count how many rows failed a specific test
SELECT COUNT(*) as failure_count
FROM AIRBNB.DEV.dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values;
```

**4. Analyze failure patterns:**
```sql
-- For accepted_values test, see which invalid values appear and how often
SELECT 
    value_field,
    COUNT(*) as occurrence_count
FROM AIRBNB.DEV.dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values
GROUP BY value_field
ORDER BY occurrence_count DESC;

-- For unique test, see duplicate values
SELECT 
    listing_id,
    COUNT(*) as duplicate_count
FROM AIRBNB.DEV.dbt_test_failure_unique_dim_listings_cleansed_listing_id
GROUP BY listing_id
ORDER BY duplicate_count DESC;
```

##### Example: Debugging with Stored Failures

**Scenario**: The `accepted_values` test on `room_type` fails.

**1. Run the test:**
```bash
$ dbt test --select dim_listings_cleansed
✗ FAIL accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values
  Got 1 result, configured to fail if != 0
```

**2. Query the failure table in Snowflake:**
```sql
SELECT *
FROM AIRBNB.DEV.dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values;
```

**Result:**
```
value_field        | n_records
-------------------|----------
Hotel room, break  | 5
```

**3. Get more details about the failing records:**
```sql
-- Query the actual model to see which listings have the invalid room_type
SELECT 
    listing_id,
    listing_name,
    room_type,
    host_id
FROM AIRBNB.DEV.dim_listings_cleansed
WHERE room_type = 'Hotel room, break';
```

**4. Fix the issue:**
Now you can see exactly which records are problematic and fix them in your model logic or update the test configuration.

##### Why `store_failures` Is Useful

1. **Direct Database Access**: Query failing rows directly in your data warehouse without needing to run SQL manually or check compiled files

2. **Persistent Debugging**: Failure tables persist between test runs, allowing you to investigate issues even after the test command completes

3. **Efficient Investigation**: No need to re-run tests or compile SQL - the failing data is already available in tables

4. **Data Analysis**: Perform complex queries on failure tables to understand patterns, trends, and root causes

5. **Team Collaboration**: Other team members can query the same failure tables to understand issues without running tests themselves

6. **Automated Monitoring**: Can be integrated into monitoring dashboards or alerts that query failure tables

7. **Historical Tracking**: Failure tables can be preserved to track data quality trends over time (if not dropped between runs)

##### Table Lifecycle

- **Creation**: Tables are created automatically when a test fails (if they don't already exist)
- **Updates**: On subsequent test runs, tables are refreshed with current failure data
- **Cleanup**: Tables are not automatically dropped - you may want to clean them up periodically:
  ```sql
  -- Drop a specific failure table
  DROP TABLE IF EXISTS AIRBNB.DEV.dbt_test_failure_accepted_values_dim_listings_cleansed_room_type__room_type__accepted_values;
  
  -- Or drop all failure tables (be careful!)
  -- You can use dbt's clean command or manually drop them
  ```

##### Configuration Options

You can also configure `store_failures` at different levels:

**Project level** (current configuration in `dbt_project.yml`):
```yaml
data_tests:
  +store_failures: true  # Applies to all tests
```

**Model level** (in `schema.yml`):
```yaml
models:
  - name: dim_listings_cleansed
    columns:
      - name: room_type
        tests:
          - accepted_values:
              arguments:
                values: [...]
              config:
                store_failures: true  # Only for this specific test
```

**Test level** (using `config()` in a singular test):
```sql
-- In tests/my_custom_test.sql
{{ config(store_failures=true) }}

SELECT * FROM ...
```

##### Best Practices

1. **Enable for Development**: Always use `store_failures: true` during development to speed up debugging

2. **Monitor Storage**: Be aware that failure tables consume storage space - clean them up periodically if needed

3. **Use in CI/CD**: Consider enabling in CI/CD pipelines to capture failure data for analysis

4. **Query Patterns**: Create reusable SQL queries or views for common failure analysis patterns

5. **Documentation**: Document the failure table naming convention for your team

6. **Cleanup Strategy**: Establish a cleanup strategy (manual or automated) for old failure tables

##### Comparison: Compiled Files vs. Stored Failures

| Feature | Compiled Files | Stored Failures |
|---------|---------------|-----------------|
| **Location** | Local `target/compiled/` | Data warehouse tables |
| **Content** | SQL query | Actual failing rows |
| **Access** | File system | SQL queries |
| **Persistence** | Until next compile | Until manually dropped |
| **Use Case** | Understanding test logic | Seeing actual failing data |
| **Best For** | Learning, customization | Quick debugging, analysis |

**Use both approaches together** for comprehensive debugging:
1. Use compiled files to understand what the test is checking
2. Use stored failures to see exactly which rows are failing
3. Query the failure tables to analyze patterns and root causes

### Build

The `dbt build` command is a powerful all-in-one command that runs models, tests, seeds, and snapshots in a single operation, following the dependency graph. It's the recommended command for production pipelines and CI/CD workflows.

#### How It Works

The `dbt build` command combines multiple dbt operations into one:

1. **Executes in dependency order**: dbt analyzes the dependency graph and executes resources in the correct order:
   - Seeds are loaded first (if selected)
   - Source freshness checks run (if configured)
   - Models are built following their dependencies (sources → dimensions → facts → marts)
   - Tests run immediately after their parent models
   - Snapshots are updated

2. **Stops on failure**: If any resource fails (model, test, or snapshot), dbt stops execution and reports the error. This ensures data quality by preventing downstream models from running with bad data.

3. **Atomic operations**: Each model-test pair is treated as an atomic unit. If a test fails, dbt won't continue building downstream models that depend on the failed model.

4. **Comprehensive execution**: Unlike running `dbt run` followed by `dbt test` separately, `dbt build` ensures tests run immediately after their models, catching issues early.

#### How to Use

To build everything (models, tests, seeds, snapshots):
```bash
cd airbnb
dbt build
```

To build specific models and their tests:
```bash
dbt build --select src_listings
```

To build a model and all downstream dependencies:
```bash
dbt build --select src_listings+
```

To build models in a directory:
```bash
dbt build --select src.*
```

To build with full refresh on incremental models:
```bash
dbt build --full-refresh
```

To exclude tests from the build:
```bash
dbt build --exclude test_type:data
```

#### Why It's Useful

1. **Single Command Execution**: Instead of running multiple commands (`dbt seed`, `dbt run`, `dbt test`, `dbt snapshot`), you can execute everything with one command, reducing complexity and potential for errors.

2. **Dependency Management**: dbt automatically handles the execution order based on dependencies, ensuring models are built before their dependents and tests run after their models.

3. **Fail-Fast Behavior**: If a test fails, dbt stops execution immediately, preventing downstream models from being built with incorrect data. This saves time and compute resources.

4. **CI/CD Integration**: Perfect for automated pipelines where you want a single command that validates the entire project. If `dbt build` succeeds, you know everything is working correctly.

5. **Data Quality Assurance**: Tests run automatically after models, ensuring data quality issues are caught immediately rather than discovered later in the pipeline.

6. **Production-Ready**: The recommended approach for production environments where you need reliability and comprehensive validation.

7. **Efficiency**: More efficient than running commands separately because dbt can optimize the execution plan and avoid redundant operations.

#### Comparison with Separate Commands

**Traditional approach** (multiple commands):
```bash
dbt seed
dbt run
dbt test
dbt snapshot
```
- If a test fails, you've already built all models
- No automatic dependency ordering across commands
- More verbose and error-prone

**Modern approach** (single command):
```bash
dbt build
```
- Stops immediately if a test fails
- Automatic dependency management
- Single command, less error-prone

#### Example Workflow

For a complete end-to-end build of this project:
```bash
cd airbnb
dbt build
```

This will:
1. Load seeds (e.g., `seed_full_moon_dates`)
2. Build source models (`src_listings`, `src_hosts`, `src_reviews`)
3. Run tests on source models
4. Build dimension models (`dim_listings_cleansed`, `dim_hosts_cleansed`, `dim_listings_w_hosts`)
5. Run tests on dimension models
6. Build fact models (`fct_reviews`)
7. Run tests on fact models
8. Build mart models (`mart_fullmoon_reviews`)
9. Run tests on mart models
10. Update snapshots (`scd_raw_listings`, `scd_raw_hosts`)

If any step fails, the process stops and reports the error.

#### Best Practices

- Use `dbt build` in CI/CD pipelines for comprehensive validation
- Use `dbt build` in production schedules to ensure data quality
- Use `dbt run` for faster iteration during development when you don't need to run tests
- Use `dbt build --select` to build specific parts of your DAG
- Combine with `--full-refresh` when you need to rebuild incremental models from scratch

### Source Freshness

The `dbt source freshness` command checks the freshness of data in your sources defined in the `sources.yml` file. This command is essential to ensure that the data feeding your models is up-to-date and not stale.

#### How It Works

The `dbt source freshness` command works as follows:

1. **Configuration in `sources.yml`**: You define freshness rules for each source table using the `loaded_at_field` and `freshness` fields:
   ```yaml
   - name: reviews
     identifier: raw_reviews
     config:
       loaded_at_field: date
       freshness:
         warn_after: {count: 1, period: hour}
         error_after: {count: 24, period: hour}
   ```

2. **Command execution**: dbt queries the field specified in `loaded_at_field` (in the example above, the `date` field) and compares it with the current time.

3. **Threshold verification**:
   - If the data is older than `warn_after`, dbt emits a warning
   - If the data is older than `error_after`, dbt returns an error and stops execution

#### How to Use

To check the freshness of all sources:
```bash
cd airbnb
dbt source freshness
```

To check a specific source:
```bash
dbt source freshness --select source:airbnb
```

To check a specific table:
```bash
dbt source freshness --select source:airbnb.reviews
```

#### Why It's Useful

1. **Pipeline Problem Detection**: Identifies when data is not being updated as expected, alerting about possible failures in ETL/ELT processes.

2. **Data Quality Assurance**: Ensures you are working with recent and relevant data, avoiding analyses based on outdated information.

3. **CI/CD Integration**: Can be used in CI/CD pipelines to block executions when data is too stale, preventing the generation of reports or dashboards with obsolete information.

4. **Proactive Monitoring**: Allows detecting problems before they affect critical analyses or business decisions.

5. **Automatic Documentation**: The freshness check result appears in the documentation generated by dbt (`dbt docs`), providing visibility into the state of the data.

#### Example Output

When you run `dbt source freshness`, you will see something like:
```
Found 3 sources
Checking freshness of 3 sources

Freshness check for source airbnb.reviews:
  Status: PASS
  Age: 2 hours
  Max allowed age: 24 hours
```

Or, if the data is stale:
```
Freshness check for source airbnb.reviews:
  Status: ERROR
  Age: 25 hours
  Max allowed age: 24 hours
```

#### Project Configuration

In this project's `sources.yml` file, the `reviews` table is configured to:
- Emit a warning if the data is older than 1 hour
- Return an error if the data is older than 24 hours

This ensures you are quickly alerted if review data is not being updated regularly.

### Snapshots

The `dbt snapshot` command captures point-in-time snapshots of your data, allowing you to track how data changes over time. This is essential for implementing Slowly Changing Dimensions (SCD) Type 2, auditing data changes, and maintaining historical records.

#### How It Works

Snapshots work by:

1. **Configuration in snapshot files**: You define snapshot configurations (like `raw_listings_snapshot.yml`) that specify:
   - The source table or model to snapshot
   - A unique key to identify records
   - A strategy for detecting changes (timestamp or check)
   - An `updated_at` field to track when records change

2. **First execution**: When you run `dbt snapshot` for the first time, dbt creates a snapshot table with all current records from the source, plus metadata columns:
   - `dbt_scd_id`: Unique identifier for each snapshot record
   - `dbt_updated_at`: Timestamp when the snapshot was taken
   - `dbt_valid_from`: When this version of the record became valid
   - `dbt_valid_to`: When this version was superseded (NULL for current records)

3. **Subsequent executions**: On each run, dbt:
   - Compares current source data with the last snapshot
   - Identifies new records, changed records, and deleted records
   - Inserts new versions of changed records
   - Marks old versions as invalid (sets `dbt_valid_to`)
   - When a record is deleted from the source, marks it as invalidated by setting `dbt_valid_to` to the snapshot execution timestamp

#### Snapshot Strategy: Timestamp

This project uses the **timestamp strategy** for all snapshots. The snapshots are configured as follows:

**`scd_raw_listings`** (in `airbnb/snapshots/raw_listings_snapshot.yml`):
```yaml
snapshots:
  - name: scd_raw_listings
    relation: source('airbnb', 'listings')
    config:
      unique_key: id
      updated_at: updated_at
      strategy: timestamp
```

**`scd_raw_hosts`** (in `airbnb/snapshots/raw_hosts_snapshot.yml`):
```yaml
snapshots:
  - name: scd_raw_hosts
    relation: source('airbnb', 'hosts')
    config:
      unique_key: id
      updated_at: updated_at
      strategy: timestamp
```

Both configurations:
- Use `id` as the unique identifier for each record
- Detect changes by comparing the `updated_at` timestamp
- When a record is deleted from the source, mark it as invalidated (set `dbt_valid_to`) rather than deleting it from the snapshot

**Deletion Behavior**: When a record is deleted from the source table, dbt automatically detects the deletion on the next snapshot run. The most recent version of the record in the snapshot (the one with `dbt_valid_to = NULL`) will have its `dbt_valid_to` field set to the snapshot execution timestamp (`dbt_updated_at`). This preserves the complete history of the record, including when it was deleted, which is essential for audit trails and historical analysis.

#### How to Use

To run all snapshots:
```bash
cd airbnb
dbt snapshot
```

To run a specific snapshot:
```bash
dbt snapshot --select scd_raw_listings
# or
dbt snapshot --select scd_raw_hosts
```

#### Why It's Useful

1. **Historical Data Tracking**: Snapshots preserve the state of your data at different points in time, allowing you to answer questions like "What was the price of this listing last month?" or "When did this host become a superhost?"

2. **Slowly Changing Dimensions (SCD) Type 2**: Snapshots implement SCD Type 2 automatically, creating a complete audit trail of all changes. This is essential for:
   - Compliance and auditing requirements
   - Trend analysis over time
   - Understanding data evolution

3. **Data Quality Monitoring**: By comparing snapshots, you can detect unexpected changes, data quality issues, or anomalies in your source data.

4. **Point-in-Time Analysis**: You can reconstruct the state of your data at any point in time by querying snapshot tables with appropriate `dbt_valid_from` and `dbt_valid_to` filters.

5. **Change Detection**: Snapshots automatically detect and record all changes without requiring manual intervention or complex change detection logic.

6. **Audit Trail**: Provides a complete audit trail of data changes, which is valuable for debugging, compliance, and understanding data lineage.

#### Example Use Cases

**Listings Snapshot**: The `scd_raw_listings` snapshot tracks changes to listing data. If a listing's price changes from $100 to $150, the snapshot will:
- Keep the old record with `dbt_valid_to` set to the change timestamp
- Create a new record with the updated price and `dbt_valid_from` set to the change timestamp
- Both records remain in the snapshot table, allowing you to see the full history

**Hosts Snapshot**: The `scd_raw_hosts` snapshot tracks changes to host data. If a host becomes a superhost, the snapshot will:
- Preserve the previous record showing the host was not a superhost
- Create a new record showing the superhost status with the appropriate timestamps
- Enable historical analysis of when hosts achieved superhost status

**Deletion Example**: If a listing is deleted from the source table, on the next snapshot run:
- The snapshot detects the record no longer exists in the source
- The most recent snapshot record (with `dbt_valid_to = NULL`) is updated
- `dbt_valid_to` is set to the snapshot execution timestamp
- The record remains in the snapshot table, preserving the deletion event for audit purposes

#### Best Practices

- Run snapshots regularly (e.g., daily) to capture changes frequently
- Use snapshots for critical source tables that change over time
- Consider the storage implications of maintaining historical snapshots
- Deleted records are automatically preserved in snapshots (with `dbt_valid_to` set to the deletion timestamp) for audit purposes
- Query snapshot tables using `dbt_valid_from` and `dbt_valid_to` to get point-in-time views

### Documentation

To generate and view project documentation:
```bash
dbt docs generate
dbt docs serve
```

## Data Pipeline

The data pipeline flow:

1. **Raw Data**: Data from Inside Airbnb is loaded into Snowflake in the `AIRBNB.RAW` schema
2. **Snapshots**: dbt snapshots capture point-in-time states of raw data (`scd_raw_listings`, `scd_raw_hosts`) for historical tracking and SCD Type 2
3. **Source Models**: dbt models in the `src/` directory transform raw data into clean, standardized formats
4. **Dimension Models**: Clean dimension models (`dim_listings_cleansed`, `dim_hosts_cleansed`, `dim_listings_w_hosts`) provide standardized attributes for analytics
5. **Fact Models**: Fact models (`fct_reviews`) aggregate and structure transactional data
6. **Mart Models**: Mart models (`mart_fullmoon_reviews`) combine facts and dimensions for business intelligence
7. **Analytics**: Clean models can be used for further analysis, reporting, and visualization

## Snowflake Integration

This project is integrated with Snowflake and reads from the following raw tables:
- `AIRBNB.RAW.RAW_LISTINGS`
- `AIRBNB.RAW.RAW_HOSTS`
- `AIRBNB.RAW.RAW_REVIEWS`

Ensure these tables exist in your Snowflake instance and contain the expected data structure before running the dbt models.

## License

The data used in this project is licensed under a Creative Commons Attribution 4.0 International License, as provided by Inside Airbnb.

## Resources

- [dbt Documentation](https://docs.getdbt.com/docs/introduction)
- [Inside Airbnb Data](https://insideairbnb.com/)
- [Snowflake Documentation](https://docs.snowflake.com/)

## Contributing

When contributing to this project, please ensure:
- All SQL follows the project's style guidelines
- Models are properly documented
- Tests are added for new models
- Changes are tested before committing

