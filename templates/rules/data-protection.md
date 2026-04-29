---
id: data-protection
patterns:
  - {{SOURCE_PATTERNS}}
---

# Data Protection Rules

When editing any source file, enforce these data protection rules. These prevent GDPR violations, credential exposure, and PII leakage.

## No Real Data in Version Control

- **NEVER commit real PII** to git — no personal numbers (personnummer/SSN), names, email addresses, medical records, salary data, or phone numbers in tracked files.
- **NEVER commit database files** (`.db`, `.sqlite`, `.sqlite3`, dumps, backups) containing real data. Use synthetic/fake test data only.
- **NEVER commit uploaded files** with real user data (Excel exports, PDFs, images). Add upload directories to `.gitignore`.
- If you find real data in tracked files, flag it immediately — it must be removed from git history with `git filter-repo`, not just deleted.
- Test fixtures and seed data must use obviously fake data (e.g., "Jane Doe", "test@example.com", "19850101-0000").

## No Credentials on Disk

- `.env` files should contain **placeholder values only** (e.g., `OPENAI_API_KEY=your-key-here`). Real credentials belong in a vault (Azure Key Vault, AWS Secrets Manager, etc.) or CI secrets.
- Commit a `.env.example` with placeholder values. Never commit `.env` with real values.
- If you find real API keys, tokens, or secrets in any file (including `.env` on disk), flag it — the credentials must be rotated immediately.
- Default values for secrets must be obviously invalid (e.g., `"CHANGE-ME-IN-PRODUCTION"`) and the application must refuse to start in production with the default.
- **Never place secrets in client-exposed environment variables** (`NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`, `NUXT_PUBLIC_*`). These are compiled into the frontend JavaScript bundle and visible to all users. Only public, non-sensitive values belong in client-prefixed env vars.

## Sensitive Data in Logs

- **NEVER log PII** — personal numbers, names, email addresses, medical data, salary information, or any data that identifies a person.
- Use opaque identifiers (case IDs, hashed values) in log messages instead of PII.
- If the project uses a structured logger (Pino, Winston, Python logging), ensure sensitive field redaction is configured.
- Error messages returned to users must not contain PII from other users or internal system details.

## Third-Party Data Sharing

- **Flag any code that sends PII or sensitive data to external APIs** (AI providers, analytics, error tracking, third-party services).
- For GDPR-regulated data (especially Article 9 special categories: health, biometric, genetic data), verify:
  - A Data Processing Agreement (DPA) exists with the third party
  - Data residency requirements are met (EU data staying in EU)
  - The minimum necessary data is sent (don't send full records when only a summary is needed)
- AI API calls with sensitive data should use zero-data-retention options where available (e.g., OpenAI's ZDR, Azure OpenAI in-tenant).

## Data Classification in Code

- When handling sensitive data, comment the sensitivity level at the boundary where it enters the system:
  - `// PII: personnummer from user input`
  - `// SENSITIVE: medical certificate data`
  - `// FINANCIAL: salary transaction records`
- This helps reviewers and future developers understand what data flows through each function.
