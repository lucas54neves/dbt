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
│   │   └── src/
│   │       ├── src_listings.sql
│   │       ├── src_hosts.sql
│   │       └── src_reviews.sql
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

### Testing

To run tests on your models:
```bash
dbt test
```

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

