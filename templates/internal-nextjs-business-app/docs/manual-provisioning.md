# Manual Provisioning Runbook

Use this runbook for the v0 pilot before a portal exists. The goal is to create a private, stamped repo with a named owner and a clear audit trail.

## Inputs

Collect these fields from the requester:

| Field | Source | Example |
|---|---|---|
| Owner email | SSO / requester | `jordan.lee@example.com` |
| Owner display name | SSO / requester | `Jordan Lee` |
| Division | SSO group / requester | `Finance` |
| Project name | Intake | `Approval Tracker` |
| Project slug | Intake | `finance-approval-tracker` |
| Description | Intake | One short paragraph |
| Who it is for | Intake | `Finance coordinators` |
| Why it exists | Intake | `Reduce spreadsheet handoffs` |
| Expected users | Intake | `just me` or `my team` |
| Template version | Maintainer | Release tag or commit SHA |
| Provisioned at | Maintainer | UTC timestamp |

## Steps

1. Confirm the request is Layer 1 suitable. If the user expects confidential, regulated, customer, or business-critical use, stop and route to IT.
2. Create a private repo in the pilot GitHub org from the audited template tag or recorded commit SHA.
3. Clone the new repo locally.
4. Replace every token in `LAYER.md.template` using the intake fields.
5. Rename `LAYER.md.template` to `LAYER.md`.
6. Prepend this owner block to `README.md`:

   ```markdown
   > Owner: <owner display> <<owner email>>
   > Division: <division>
   > Project: <project name>
   > Provisioned from: <template version>
   ```

7. Verify the stamped seed files contain no unresolved intake tokens:

   ```bash
   grep -n "<<intake:" LAYER.md README.md CLAUDE.md 2>/dev/null
   ```

   The command should produce no output. Documentation files may still mention token names as examples.
8. Commit the stamp as the provisioning identity:

   ```bash
   git add LAYER.md README.md
   git commit -m "Initialize project from intake by <owner email>"
   ```

9. Add repo topics such as `claude-code-framework`, `layer-1`, `division-<slug>`, and `template-<version>`.
10. Add the owner with the agreed pilot permission level.
11. Record the provisioning event in the pilot audit spreadsheet: who, when, repo URL, template version, intake fields, and any blocked/routed requests.
12. Send the owner the repo URL and point them to `START_HERE.md`.

## Done Criteria

- `LAYER.md` exists.
- `LAYER.md.template` does not exist.
- The owner can clone the repo.
- The audit spreadsheet links the requester, repo, and template version.
- The owner can run `npm run doctor` and knows what to fix if it reports missing tools.
