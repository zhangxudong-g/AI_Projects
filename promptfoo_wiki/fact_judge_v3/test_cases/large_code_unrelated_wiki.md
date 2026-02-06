# Database Schema Documentation

## Table: Orders

The Orders table contains information about customer orders.

### Columns:
- order_id: Unique identifier for each order
- customer_id: Reference to the customer who placed the order
- order_date: Date when the order was placed
- total_amount: Total monetary value of the order
- status: Current status of the order (pending, shipped, delivered, cancelled)

### Relationships:
- Links to Customers table via customer_id
- May link to OrderItems table for detailed items

## Indexes:
- Primary index on order_id
- Foreign key index on customer_id
- Index on order_date for date range queries

## Constraints:
- order_id must be unique
- customer_id must reference an existing customer
- total_amount must be positive
- status must be one of the predefined values

## Performance Notes:
- This table is frequently queried
- Consider partitioning by date
- Regular maintenance required for optimal performance