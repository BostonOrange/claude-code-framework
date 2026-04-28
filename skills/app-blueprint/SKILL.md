---
name: app-blueprint
description: Convert internal business app intent into a structured JSON blueprint for the app generator.
---

# App Blueprint

Turn business intent into a concrete internal-app blueprint. Use this before generating or materially changing an internal Next.js business app.

## Usage

```
/app-blueprint Build an approval app for supplier invoices
/app-blueprint docs/notes/invoice-workflow.md
```

If the user gives only a rough idea, produce the best blueprint you can and mark uncertain fields in `openQuestions`. Ask only for blockers that would make generation unsafe.

## Process

1. Read the prompt and any referenced files.
2. Identify the core business workflow, users, records, file needs, audit trail, dashboards, and AI assist points.
3. Normalize names to stable identifiers:
   - `PascalCase` for entity names.
   - `camelCase` for field names.
   - lower-kebab-case for workflow and view IDs.
4. Keep the first pass small enough to generate:
   - Prefer 2-5 core entities.
   - Prefer explicit statuses over vague text fields.
   - Prefer role names that map to permissions.
5. Write the result to `docs/app-blueprint.json` unless the user requested a different path.
6. Report the blueprint path and any open questions.

## Output Contract

Write valid JSON with this shape:

```json
{
  "appName": "Supplier Invoice Desk",
  "summary": "Short operational description.",
  "usersAndRoles": [
    {
      "role": "financeManager",
      "displayName": "Finance Manager",
      "responsibilities": ["Approve invoices"],
      "authSource": "oidc"
    }
  ],
  "entities": [
    {
      "name": "Invoice",
      "description": "Supplier invoice awaiting review.",
      "fields": [
        {
          "name": "supplierName",
          "type": "string",
          "required": true,
          "unique": false,
          "sensitive": false,
          "notes": "Shown in lists and detail views."
        }
      ],
      "statuses": ["draft", "submitted", "approved", "rejected"],
      "relationships": [
        {
          "name": "attachments",
          "target": "FileObject",
          "cardinality": "many"
        }
      ]
    }
  ],
  "workflows": [
    {
      "id": "submit-invoice",
      "name": "Submit Invoice",
      "actorRoles": ["requester"],
      "entity": "Invoice",
      "fromStatuses": ["draft"],
      "toStatus": "submitted",
      "steps": ["Validate required fields", "Create audit event"]
    }
  ],
  "permissions": [
    {
      "role": "financeManager",
      "entity": "Invoice",
      "actions": ["read", "approve", "reject"]
    }
  ],
  "filesBlobNeeds": [
    {
      "entity": "Invoice",
      "purpose": "Store original invoice PDF",
      "allowedMimeTypes": ["application/pdf"],
      "maxSizeMb": 10,
      "retention": "Match finance record retention policy"
    }
  ],
  "auditEvents": [
    {
      "event": "invoice.approved",
      "actor": "financeManager",
      "entity": "Invoice",
      "payloadFields": ["invoiceId", "approvedAmount"]
    }
  ],
  "dashboardsViews": [
    {
      "id": "finance-queue",
      "name": "Finance Queue",
      "role": "financeManager",
      "type": "table",
      "entities": ["Invoice"],
      "filters": ["status", "supplierName"],
      "primaryActions": ["approve", "reject"]
    }
  ],
  "aiAssistPoints": [
    {
      "id": "invoice-review-assist",
      "name": "Invoice Review Assist",
      "trigger": "detail-view",
      "inputs": ["supplierName", "amount", "description"],
      "output": "Risk notes and recommended review checklist",
      "humanDecisionRequired": true
    }
  ],
  "openQuestions": []
}
```

## Guardrails

- Do not invent external integrations beyond what the user provided; put candidates in `openQuestions`.
- Mark fields that may contain PII or confidential data with `sensitive: true`.
- Keep file/blob needs separate from relational entity fields.
- Keep AI assist points advisory. Human workflow state changes must remain explicit actions.
