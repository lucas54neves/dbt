SELECT fr.listing_id, fr.review_date, dlc.created_at
FROM {{ ref('fct_reviews')}} fr
LEFT JOIN {{ ref('dim_listings_cleansed') }} dlc ON fr.listing_id = dlc.listing_id
WHERE fr.review_date < dlc.created_at
LIMIT 10