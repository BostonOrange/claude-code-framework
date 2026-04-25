---
id: config-files
patterns:
  - "*.json"
  - "*.yaml"
  - "*.yml"
  - "*.toml"
  - "*.env.example"
---

# Configuration File Rules

When editing configuration files, follow these rules:

## Secrets
- Never commit secrets, tokens, API keys, or credentials
- Use environment variable references instead of hardcoded values
- Placeholder values in example files must be obviously fake (e.g., `your-api-key-here`)

## Documentation
- Include comments explaining non-obvious configuration values
- Document units for numeric values (seconds, milliseconds, bytes, etc.)
- Document valid ranges or allowed values for constrained fields

## Maintenance
- Keep configuration DRY — reference shared values rather than duplicating
- Validate configuration at application startup — fail fast on missing required values
- Version configuration schemas when breaking changes are introduced
