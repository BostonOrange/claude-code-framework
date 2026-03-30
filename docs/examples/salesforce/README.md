# Example: Salesforce Project

This is the original project (Salesforce-Nexus) that the framework was extracted from.

## Setup

```bash
cd your-salesforce-project/
bash ~/Developer/claude-code-framework/setup.sh
# Choose: 1 (Salesforce), 1 (Azure DevOps), 1 (GitHub Actions), develop, 1 (Slack)
```

## Additional Domain Skills

After basic setup, add Salesforce-specific domain skills:

```bash
mkdir -p .claude/skills/fsl/references    # Field Service Lightning
mkdir -p .claude/skills/rca/references    # Revenue Cloud Advanced
mkdir -p .claude/skills/fsm/references    # Field Service Mobile
```

Then scan the codebase:
```
/add-reference fsl objects
/add-reference fsl apex-classes
/add-reference fsl flows
/add-reference fsl test-data-factories
/add-reference fsl permission-sets
/add-reference rca objects-and-fields
```

## Salesforce-Specific CLAUDE.md Sections

Add these to your CLAUDE.md:

### Apex Coding Standards
- Type capitalization: `String`, `Integer`, `Boolean`, `Decimal`, `Map`, `List`, `Set`
- Bulkify all code (handle 200+ records)
- No SOQL/DML in loops
- Error handling via `ErrorTrackingUtils.trackException()`
- Test classes: `private`, use factories, no `SeeAllData=true`

### Deployment Commands
```bash
sf project deploy validate -x manifest/package.xml -l RunLocalTests -w 30
sf project deploy start -x manifest/package.xml -o {alias}
```

### Shared Metadata Workflow
FlexiPages, Layouts, Permission Sets are shared. Use pull-merge-deploy pattern.

## What Nexus Has Beyond the Framework

| Component | Nexus-Specific |
|-----------|---------------|
| 5 domain skills | FSL, RCA, FSM, ROT/RUT, Personas |
| 50+ reference files | Object inventories, flow catalogs, PDF chapters |
| ADO Wiki integration | `/ado-wiki` skill for design doc fetching |
| Sandbox pool management | `/sandbox-pool` with GitHub Actions routing |
| Scratch org automation | `scratch-org-init.sh` with package install + filtered deploy |
| Merge conflict resolution | `/merge-resolve` with dual-story understanding |
| Integration outbox | Error write-back convention docs |
