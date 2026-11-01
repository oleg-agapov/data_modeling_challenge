-- =============================================================================
-- Data Modeling Challenge: load the e-commerce dataset into DuckDB
-- =============================================================================
--
-- Creates six tables (users, locations, products, orders, order_items,
-- user_events) with explicit column types. Running it again recreates them.
--
-- Where are the CSV files?
--   * Running locally from the repository root: leave the line below as is.
--   * Running in the browser (https://shell.duckdb.org) or anywhere without a
--     local copy: comment out the first SET line and uncomment the second one.
--
-- See GETTING_STARTED.md for step-by-step instructions.
-- =============================================================================

SET VARIABLE data_path = 'data/ecommerce/';
-- SET VARIABLE data_path = 'https://raw.githubusercontent.com/oleg-agapov/data_modeling_challenge/main/data/ecommerce/';


CREATE OR REPLACE TABLE users AS
SELECT * FROM read_csv(getvariable('data_path') || 'users.csv', header = true, columns = {
    'user_id':     'VARCHAR',
    'first_name':  'VARCHAR',
    'last_name':   'VARCHAR',
    'email':       'VARCHAR',
    'created_at':  'TIMESTAMP',
    'location_id': 'VARCHAR'
});

CREATE OR REPLACE TABLE locations AS
SELECT * FROM read_csv(getvariable('data_path') || 'locations.csv', header = true, columns = {
    'location_id':       'VARCHAR',
    'country_code':      'VARCHAR',
    'country_full_name': 'VARCHAR',
    'city':              'VARCHAR',
    'address':           'VARCHAR',
    'zip_code':          'VARCHAR',  -- text, not a number: keeps leading zeros
    'state':             'VARCHAR'
});

CREATE OR REPLACE TABLE products AS
SELECT * FROM read_csv(getvariable('data_path') || 'products.csv', header = true, columns = {
    'name':        'VARCHAR',
    'category':    'VARCHAR',
    'description': 'VARCHAR',
    'price':       'DECIMAL(12,2)',
    'dimensions':  'VARCHAR',
    'material':    'VARCHAR',
    'stock':       'INTEGER',
    'id':          'VARCHAR'   -- the primary key is the last column in this file
});

CREATE OR REPLACE TABLE orders AS
SELECT * FROM read_csv(getvariable('data_path') || 'orders.csv', header = true, columns = {
    'order_id':       'VARCHAR',
    'user_id':        'VARCHAR',
    'order_date':     'TIMESTAMP',
    'order_status':   'VARCHAR',
    'payment_method': 'VARCHAR',
    'updated_at':     'TIMESTAMP'
});

CREATE OR REPLACE TABLE order_items AS
SELECT * FROM read_csv(getvariable('data_path') || 'order_items.csv', header = true, columns = {
    'order_item_id': 'VARCHAR',
    'order_id':      'VARCHAR',
    'product_id':    'VARCHAR',
    'quantity':      'INTEGER',
    'unit_price':    'DECIMAL(12,2)',
    'discount':      'DECIMAL(4,2)',   -- a rate (0.15 = 15%), not an amount
    'line_total':    'DECIMAL(12,2)'
});

CREATE OR REPLACE TABLE user_events AS
SELECT * FROM read_csv(getvariable('data_path') || 'user_events.csv', header = true, columns = {
    'event_id':           'VARCHAR',
    'user_id':            'VARCHAR',
    'event_type':         'VARCHAR',
    'event_timestamp':    'TIMESTAMP',
    'page_url':           'VARCHAR',
    'product_id':         'VARCHAR',
    'additional_details': 'VARCHAR'
});


-- -----------------------------------------------------------------------------
-- Verify: you should see exactly these row counts.
--   users 12483 | locations 12483 | products 21 | orders 1918
--   order_items 2092 | user_events 191157
-- -----------------------------------------------------------------------------
SELECT 'users'       AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'locations',   COUNT(*) FROM locations
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'user_events', COUNT(*) FROM user_events;
