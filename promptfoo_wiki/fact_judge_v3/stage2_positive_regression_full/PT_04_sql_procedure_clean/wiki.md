## Purpose
This procedure retrieves a single user record by ID.

## Behavior
- Accepts user ID as input
- Performs a direct SELECT
- No side effects or state changes

## Modification Notes
- Index usage should be considered on users.id
- Caller responsibility for transaction scope
