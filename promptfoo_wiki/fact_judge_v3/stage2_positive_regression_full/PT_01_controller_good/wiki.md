## Purpose

This controller exposes a REST endpoint for retrieving a single user by ID.
It acts as a thin HTTP adapter and delegates all business logic to UserService.

## Responsibilities

- Validate request path variables via Spring MVC binding
- Delegate user lookup to UserService
- Convert domain User to UserDto for API response

## Control Flow

1. HTTP GET /users/{id}
2. Spring binds `id` from path
3. `userService.findById(id)` is invoked
4. Result is mapped to UserDto
5. ResponseEntity is returned

## Modification Notes

- Any change to lookup logic should be done in UserService
- This controller should remain free of business rules
- Error handling is expected to be handled by global exception handlers
