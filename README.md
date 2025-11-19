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

## Setup

1. **Install dbt** (if not already installed):
   ```bash
   pip install dbt-snowflake
   ```

2. **Configure your Snowflake connection** in `airbnb/profiles.yml`:
   ```yaml
   airbnb:
     outputs:
       dev:
         type: snowflake
         account: <your-account>
         user: <your-user>
         password: <your-password>
         role: <your-role>
         database: AIRBNB
         warehouse: <your-warehouse>
         schema: <your-schema>
     target: dev
   ```

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

To run tests on your models:
```bash
dbt test
```

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

