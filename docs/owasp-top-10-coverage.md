# OWASP Top 10 (2021) — Framework Coverage

Audit-friendly mapping of each OWASP Top 10 (2021) category to the rules and reviewer agents that own it. When `security-auditor` or any specialist flags a security finding, this table tells you which rule it cites and which agent produced it.

If a category has multiple rules / agents, that's intentional — defense in depth. The `review-coordinator` dedupes overlap per the overlap-resolution table.

## Coverage Matrix

| OWASP | Title | Rules | Primary Agent(s) | Notes |
|-------|-------|-------|------------------|-------|
| **A01** | Broken Access Control | `auth-security`, `data-protection` | `security-auditor` | RBAC, fail-closed auth, redirect validation, cross-tenant isolation, IDOR |
| **A02** | Cryptographic Failures | `crypto`, `secrets-management` | `crypto-reviewer`, `security-auditor` | Hash algorithms, password storage, RNG, encryption modes, JWT, TLS, key derivation, constant-time comparison |
| **A03** | Injection | `auth-security`, `database`, `api-routes` | `security-auditor` | SQL/XSS/command/path injection, input validation at boundaries, parameterized queries |
| **A04** | Insecure Design | `architecture-layering`, `api-layering`, `frontend-architecture`, `auth-security` | `architect` (planning), `architecture-reviewer`, `api-layering-reviewer`, `frontend-architecture-reviewer`, `risk-assessor` (planning) | Threat modeling at design time; layering; risk assessment in `/plan` |
| **A05** | Security Misconfiguration | `config-files`, `auth-security`, `crypto`, `secrets-management` | `security-auditor`, `crypto-reviewer` | Secure defaults, hardening headers, TLS config, debug flags off in production, build flags (`ignoreBuildErrors`) |
| **A06** | Vulnerable & Outdated Components | `supply-chain` | `supply-chain-reviewer`, `security-auditor` (dep audit) | Lockfile hygiene, version pinning, CVE reachability, dev/prod separation, dep update cadence |
| **A07** | Identification & Authentication Failures | `auth-security`, `crypto` (password storage / JWT) | `security-auditor`, `crypto-reviewer` | Session security, MFA, brute-force protection, JWT discipline, password policy, credential recovery |
| **A08** | Software & Data Integrity Failures | `supply-chain` | `supply-chain-reviewer` | Insecure deserialization, CI/CD pipeline integrity, package signing, build reproducibility, untrusted updates |
| **A09** | Security Logging & Monitoring Failures | `observability`, `data-protection` | `observability-reviewer`, `security-auditor` | Audit logs on sensitive operations, structured logging, no PII in logs, alerting on auth failures, correlation IDs |
| **A10** | Server-Side Request Forgery (SSRF) | `auth-security` | `security-auditor` | Outbound URL validation, private IP blocking, scheme allow-list |

## Rule → OWASP Reverse Index

| Rule | Covers OWASP |
|------|--------------|
| `auth-security` | A01, A03, A05, A07, A10 |
| `crypto` | A02, A05, A07 |
| `data-protection` | A01, A09 |
| `supply-chain` | A06, A08 |
| `observability` | A09 |
| `secrets-management` | A02, A05 |
| `database` | A03 |
| `config-files` | A05 |
| `api-routes` | A01, A03 |
| `architecture-layering` | A04 |
| `api-layering` | A04 |
| `frontend-architecture` | A04 |

## Reviewer Agent → OWASP Reverse Index

| Agent | Covers OWASP |
|-------|--------------|
| `security-auditor` | A01, A03, A05, A07, A09, A10 (broad sweep + dep audit) |
| `crypto-reviewer` | A02, A05 (crypto-specific), A07 (password storage, JWT) |
| `supply-chain-reviewer` | A06, A08 |
| `observability-reviewer` | A09 |
| `architecture-reviewer` | A04 (insecure design at the structural level) |
| `api-layering-reviewer` | A04 (insecure design at the API layering level), A01 (auth check placement) |
| `frontend-architecture-reviewer` | A04 (insecure design at the FE level) |

## Other Standards

This framework is OWASP Top 10 (2021)-aligned. Other standards we don't currently codify as separate rules:

- **OWASP ASVS (Application Security Verification Standard)** — a verification framework with three levels (L1/L2/L3). Our coverage roughly maps to L2 for most controls. If you need L3, layer additional checks per chapter.
- **SANS CWE Top 25** — overlaps significantly with OWASP Top 10; not separately tracked. Specific CWEs are cited inline in `security-auditor` findings when relevant.
- **PCI DSS / HIPAA / SOC2 / NIST 800-53 / 800-218 (SSDF)** — compliance frameworks. Not codified as rules; consult your compliance lead for control mapping. The `audit logs`, `crypto`, `secrets-management`, and `data-protection` rules contribute to most of them.

## How to Use This Doc

- **As a developer:** when a reviewer cites a rule, look up which OWASP category it maps to. Use that for ticket categorization, audit-trail evidence, or compliance reporting.
- **As an auditor:** use the matrix to verify the framework's coverage. The reverse indices show which rules/agents would catch a given category.
- **When extending the framework:** add a new rule, then update this table. New rules without OWASP mapping are fine — not everything maps. But every rule that does should be listed.

## Gaps

Honest gaps — things this framework does NOT specifically codify, even though they appear in OWASP-adjacent guidance:

- **Threat modeling as an explicit artifact.** `architect` + `risk-assessor` produce design notes but no STRIDE / PASTA-style structured threat model.
- **Deny-list of known-vulnerable dependencies** (separate from CVE scan) — `supply-chain-reviewer` checks CVEs but doesn't maintain a project-specific deny-list.
- **Compliance-specific controls** (PCI DSS QSA-checkable artifacts, HIPAA log retention specifics, SOC2 evidence collection). The framework's audit logs are structurally compatible with most of these but don't auto-generate compliance evidence.
- **Runtime application self-protection (RASP), WAF rules, IDS/IPS** — these are deployment / infra concerns, not source-code-review concerns.

If you need any of these as part of your security posture, layer them on top of the framework — don't expect the agents to catch them.
