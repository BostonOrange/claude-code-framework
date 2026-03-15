# Example: Python API Service

## Setup

```bash
cd my-python-api/
bash ~/Developer/claude-code-framework/setup.sh
# Choose: 3 (Python), 2 (Jira), 1 (GitHub Actions), main, 1 (Slack)
```

## Domain Skills to Add

### API
```
/add-reference api endpoints      # Scan FastAPI/Flask routes
/add-reference api models         # Document Pydantic models / SQLAlchemy
/add-reference api middleware     # Auth, rate limiting, error handling
```

### Database
```
/add-reference db models          # Scan Alembic migrations or models
/add-reference db queries         # Document query patterns
```

### Infrastructure
```
/add-reference infra terraform    # Scan Terraform modules
/add-reference infra docker       # Document Dockerfile and compose
```

## CLAUDE.md Additions

### Code Standards
- Type hints on all public functions
- Pydantic for request/response validation
- `structlog` for structured logging
- `pytest` fixtures over setup/teardown

### Testing
```bash
pytest                      # Run all tests
pytest -x                   # Stop on first failure
pytest --cov=app            # With coverage
mypy app/                   # Type checking
ruff check .                # Linting
black --check .             # Formatting
```

### Error Handling
```python
# Standard error tracking pattern
from app.core.errors import track_exception

try:
    result = await service.process(data)
except ServiceError as e:
    track_exception(e, source="ServiceName", context={"data_id": data.id})
    raise HTTPException(status_code=500, detail="Processing failed")
```

### Deployment
```bash
docker build -t myapi .
docker push registry.example.com/myapi:latest
kubectl rollout restart deployment/myapi
```

## Error Analyze Customization

Configure the error query for your monitoring system:

```python
# Sentry integration
import sentry_sdk
issues = sentry_sdk.get_issues(status="unresolved", since="24h")
```

Or database-backed error tracking:
```sql
SELECT source, error_type, COUNT(*) as count, MAX(created_at) as latest
FROM error_log
WHERE status = 'new' AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY source, error_type
ORDER BY count DESC;
```
