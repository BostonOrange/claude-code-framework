---
patterns:
  - "setup.sh"
  - "setup.ps1"
---

# Setup Script Rules

When editing setup scripts, follow these rules:

## Parity
- `setup.sh` and `setup.ps1` MUST have feature parity
- Every prompt, placeholder mapping, copy operation, and summary line in one must exist in the other
- Test both after changes

## Placeholder Mappings
- Every `{{PLACEHOLDER}}` used in templates must have a replacement value for ALL project types:
  salesforce, nodejs, react, python, go, java, rails, generic
- The `generic` case should use a comment like `# Configure your X command`

## Copy Operations
- All template directories (agents, commands, rules, hooks) must be copied
- Use the same directory structure: `templates/X/*.ext` → `.claude/X/*.ext`
- Set executable permissions on hook scripts (`chmod +x`)

## Conditional Logic
- Backend-only projects (python, go, java) skip `components.md` rule
- Frontend rules should apply to react, nodejs, rails, salesforce (LWC)

## Summary Output
- File counts must match actual template counts
- List all directories created with descriptions

## Portability (setup.sh only)
- Use `$SED_INPLACE` variable for portable sed (macOS vs Linux)
- Export variables before Python replacement blocks
- Avoid macOS-only commands without fallbacks
