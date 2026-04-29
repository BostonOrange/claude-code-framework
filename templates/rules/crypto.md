---
id: crypto
patterns:
  - {{SOURCE_PATTERNS}}
---

# Cryptography Rules

Citable standards used by the `crypto-reviewer` agent. Covers OWASP A02:2021 (Cryptographic Failures). Distinct from `auth-security` (auth flow / RBAC / CSRF) and `secrets-management` (storage of secrets, not their use).

The principle: **never invent crypto. Use vetted libraries with secure-by-default settings. When you must choose parameters, choose strong ones.**

## Hash Algorithms

**Detect:**
- `md5`, `sha1` used for security purposes (passwords, signatures, integrity-on-untrusted-data, key derivation)
- `crc32` or other non-cryptographic hashes used where collision resistance matters
- Custom hash constructions ("our security hash combines SHA256 + a secret prefix")

**Allow:**
- `md5` / `sha1` for non-security purposes (cache keys, ETags, content-addressable storage where collisions are tolerable)

**Fix:**
- Passwords → use a password hasher (bcrypt / argon2id / scrypt), not a general-purpose hash. See "Password Storage" below.
- Integrity / signing → SHA-256 or SHA-3, with HMAC if a key is involved
- Don't roll your own MAC; use HMAC-SHA-256 or a vetted library's `Mac` API

## Password Storage

**Detect:**
- Passwords hashed with `sha256(password)` / `sha256(password + salt)` / any general-purpose hash
- Password hashers with cost parameters below current OWASP recommendations
- Passwords compared with `==` instead of constant-time comparison (timing attack)
- Passwords logged, returned in API responses, or stored in plaintext anywhere

**Fix:**
- Use `argon2id` (preferred) or `bcrypt` (cost ≥ 12) or `scrypt` (N ≥ 2^17)
- Compare via the library's `verify` function (constant-time)
- Never log password fields; redact in error responses
- Store the algorithm name + parameters with the hash so future migrations work (`argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>`)

## Random Number Generation

**Detect:**
- `Math.random()`, `random.random()`, `rand()` used for tokens, session IDs, password reset codes, nonces, salts, or any security-sensitive value
- Predictable seeds (`Random(0)`, `Random(timestamp)`) for security-relevant generation
- "Custom" RNG functions

**Fix:**
- Use a CSPRNG: `crypto.randomBytes()` (Node), `secrets` (Python), `crypto/rand` (Go), `SecureRandom` (Java), `os.urandom`
- Token generators should use ≥128 bits of entropy (16 bytes), encoded as base64url or hex
- Never seed a CSPRNG manually

**Allow:** `Math.random()` for non-security purposes (UI animations, jitter, sampling)

## Symmetric Encryption

**Detect:**
- `AES` with no mode specified (defaults to ECB in some libraries) — ECB leaks patterns, never use
- `AES-CBC` without a unique IV per encryption, or with predictable IVs
- `AES-CBC` without a MAC (encrypt-then-MAC), enabling padding-oracle attacks
- Custom block-mode constructions
- Encryption with the same key for unrelated purposes

**Fix:**
- Use AEAD: `AES-256-GCM`, `ChaCha20-Poly1305`, or libsodium's `secretbox`
- Generate a fresh random IV/nonce for every encryption (CSPRNG)
- Use a separate key per purpose; derive subkeys via HKDF when needed
- Never reuse a `(key, nonce)` pair under GCM — that breaks the MAC

## Asymmetric Cryptography

**Detect:**
- RSA-1024 or smaller (compromised; use ≥2048, prefer 3072+)
- RSA without OAEP padding (`PKCS1v1.5` is vulnerable)
- ECDSA without verifying that signatures are in canonical form (malleability)
- Custom curves or "homemade" elliptic-curve code
- Key generation without a CSPRNG

**Fix:**
- RSA: ≥2048 bits, OAEP padding for encryption, PSS padding for signatures
- ECDSA / Ed25519: prefer Ed25519 for signing (modern, deterministic, no malleability)
- Use the library's high-level APIs, not low-level primitives
- Verify signatures before deserializing data

## Key Derivation

**Detect:**
- Keys derived from passwords via plain hashing (`sha256(password)`)
- Same key used for multiple unrelated purposes
- Keys hardcoded in source

**Fix:**
- Passwords → keys: use PBKDF2 (≥600,000 iterations for SHA-256), Argon2, or scrypt
- Key separation: HKDF with distinct `info` per purpose
- Hardcoded keys → load from secrets management (cited by `secrets-management` rule)

## TLS / Transport

**Detect:**
- TLS 1.0 / 1.1 enabled (deprecated; use 1.2+ minimum, prefer 1.3)
- Weak cipher suites enabled (RC4, 3DES, NULL, EXPORT)
- Certificate verification disabled in client code (`verify=False`, `rejectUnauthorized: false`, `InsecureSkipVerify: true`)
- HTTP used where HTTPS is available (especially for auth, payment, PII)
- HSTS not configured on web responses
- Mixed content (HTTPS page loading HTTP resources)

**Fix:**
- Minimum TLS 1.2; prefer 1.3
- Disable known-weak cipher suites
- Always verify certificates in production code
- HSTS with `max-age=31536000; includeSubDomains; preload` for production
- Redirect HTTP to HTTPS at the edge

## JWT Discipline

**Detect:**
- `alg: "none"` accepted by the verifier (CVE class)
- Algorithm specified by the token rather than pinned by the verifier (key-confusion attacks)
- HMAC verifiers that accept asymmetric keys (RS256 → HS256 attack)
- JWTs without expiry (`exp`)
- JWTs verified without checking `iss`, `aud`
- Long-lived JWTs used as session tokens (revocation impossible)
- Sensitive data in the JWT payload (it's signed, not encrypted — readable by anyone)

**Fix:**
- Pin the algorithm in the verifier; reject anything else
- Use asymmetric (RS256, ES256, EdDSA) for distributed verification; symmetric (HS256) only when the same service issues and verifies
- Always set and check `exp`, `iss`, `aud`
- For session-like use cases, prefer opaque tokens with server-side revocation
- Never put PII or secrets in the JWT body — encrypt with JWE if needed

## Constant-Time Comparison

**Detect:**
- `==` / `===` / `strcmp` comparing tokens, signatures, MACs, password hashes
- Early-exit comparison loops over secret material

**Fix:**
- Use `crypto.timingSafeEqual` (Node), `hmac.compare_digest` (Python), `subtle.ConstantTimeCompare` (Go), `MessageDigest.isEqual` (Java)

## Cryptographic Agility

**Detect:**
- Algorithm baked into stored data with no version tag (impossible to migrate)
- Application that doesn't track what algorithm/parameters produced existing hashes/ciphertexts

**Fix:**
- Store algorithm + parameters with output (`argon2id$v=19$...`, `aes-256-gcm$<nonce>$<ct>`)
- Plan re-hash on next login for legacy passwords; plan re-encrypt jobs for legacy ciphertexts

## What NOT to Flag

- **Non-security uses of weak hashes** (cache keys, ETags, content addressing)
- **`Math.random()` outside security paths** (UI, sampling)
- **TLS hardening flagged at code level** when the project terminates TLS at a load balancer / CDN that enforces it (verify the deployment, not the code)
- **Vendored / generated crypto code** from a vetted library
- **Test fixtures with weak crypto** for testing the algorithm itself
- **Pre-existing crypto in unchanged files** — only flag changes within the diff
- **JWT discussions for systems that don't use JWTs**
