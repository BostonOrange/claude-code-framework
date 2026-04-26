---
id: database
patterns:
  - {{DATABASE_PATTERNS}}
---

# Database Rules

When editing database-related files, follow these rules:

## Query Safety
- Never execute raw SQL from user input — always use parameterized queries
- No string concatenation or template literals for building SQL queries
- Use the ORM/query builder — drop to raw SQL only with parameterized queries when the ORM cannot express the query

## Performance
- Add database indexes for foreign keys and frequently queried columns
- No queries inside loops — use batch operations, joins, or eager loading
- Add `LIMIT` to queries that could return unbounded result sets
- Use `EXPLAIN` or query plan analysis for complex queries

## Migrations
- Migrations must be reversible — include both up and down operations
- Never modify a migration that has been deployed — create a new migration
- Test migrations against a copy of production data structure
- Add appropriate constraints at the database level (NOT NULL, UNIQUE, CHECK, FOREIGN KEY)

## Transactions
- Use transactions for multi-step operations that must be atomic
- Keep transactions as short as possible — no external API calls inside transactions
- Handle transaction rollback explicitly on error
