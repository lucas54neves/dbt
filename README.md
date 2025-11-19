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
│   │   │   └── dim_listings_cleansed.sql
│   │   ├── fct/
│   │   │   └── fct_reviews.sql
│   │   ├── mart/
│   │   │   └── mart_fullmoon_reviews.sql
│   │   └── sources.yml
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

### Documentation

To generate and view project documentation:
```bash
dbt docs generate
dbt docs serve
```

## Data Pipeline

The data pipeline flow:

1. **Raw Data**: Data from Inside Airbnb is loaded into Snowflake in the `AIRBNB.RAW` schema
2. **Source Models**: dbt models in the `src/` directory transform raw data into clean, standardized formats
3. **Analytics**: Clean models can be used for further analysis, reporting, and visualization

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

