---
name: team
description: Spawn pre-configured agent teams for parallel review, analysis, or implementation tasks
---

# Team — Agent Group Orchestration

Spawn a team of specialized agents to work in parallel on the current codebase.

## Usage

```
/team review          — Code reviewer + Security auditor + UI/UX reviewer
/team architecture    — Architect + API designer + Database architect
/team release         — Security auditor + DevOps engineer + Performance optimizer
/team quality         — Code reviewer + Test writer + Performance optimizer
/team documentation   — Documentation writer + API designer
/team full            — All agents (12)
/team custom agent1 agent2 agent3   — Pick specific agents
```

## Available Agents

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| `architect` | System design, patterns, structural risks | opus | Read-only |
| `code-reviewer` | Bugs, security, performance in diff | opus | Read-only |
| `security-auditor` | OWASP audit, credentials, dependencies | opus | Read-only |
| `test-writer` | Generate tests for changed code | opus | Read/Write |
| `devops-engineer` | CI/CD, infra, deployment readiness | opus | Read-only |
| `ui-ux-reviewer` | Accessibility, design, responsiveness | opus | Read-only |
| `performance-optimizer` | Bundle, queries, rendering, caching | opus | Read-only |
| `documentation-writer` | API docs, READMEs, architecture docs | opus | Read/Write |
| `api-designer` | Endpoint design, schemas, consistency | opus | Read-only |
| `database-architect` | Schema, migrations, indexes, queries | opus | Read-only |
| `framework-improver` | Self-improvement of .claude/ config | opus | Read/Write |

## Process

### Phase 1: Parse Team Request

Parse the team name from the command argument. Map to agent list:

| Team | Agents |
|------|--------|
| `review` | code-reviewer, security-auditor, ui-ux-reviewer |
| `architecture` | architect, api-designer, database-architect |
| `release` | security-auditor, devops-engineer, performance-optimizer |
| `quality` | code-reviewer, test-writer, performance-optimizer |
| `documentation` | documentation-writer, api-designer |
| `full` | all 12 agents |
| `custom` | agents listed after "custom" keyword |

If no argument provided, show usage and available teams.

### Phase 2: Spawn Agents in Parallel

For each agent in the team, spawn it as a sub-agent using the Agent tool:
- Set `subagent_type` to the agent name from `.claude/agents/`
- Run all agents in parallel (single message with multiple Agent tool calls)
- Each agent works independently on the codebase

### Phase 3: Collect Results

Wait for all agents to complete. Each returns a structured report.

### Phase 4: Synthesize Team Report

Combine individual reports into a unified team report:

```
## Team Report: {team-name}

### Agent Results Summary

| Agent | Status | Critical | Warnings | Notes |
|-------|--------|----------|----------|-------|
| {name} | Complete | {n} | {n} | {n} |

### Critical Findings (cross-team)
{deduplicated critical findings from all agents}

### Action Items (prioritized)
1. {highest priority item from any agent}
2. {next priority}
...

### Individual Reports
{link or summary of each agent's full report}
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Unknown team name | Show available teams and usage |
| Agent fails | Report failure, continue with other agents |
| No changed files | Agents analyze full codebase (may be slow) |
| `custom` with no agents listed | Show available agents |
| Single agent specified | Run just that one agent (no team overhead) |

## Related Skills

- `/improve` — Uses framework-improver agent to update .claude/ configuration
- `/validate` — Code validation (more focused than /team review)
