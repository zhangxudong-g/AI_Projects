## Purpose
This service provides a thin coordination layer for retrieving Order entities.

## Responsibilities
- Delegate persistence access to OrderRepository
- Avoid embedding business rules

## Control Flow
1. Caller invokes find(id)
2. Repository lookup is delegated
3. Result is returned as-is

## Modification Notes
- Add validation or transaction handling here if needed
- Keep repository contract unchanged
