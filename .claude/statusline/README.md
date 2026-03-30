# Claude Code Status Line

A 4-line status bar for Claude Code that shows project context at a glance.

```
[Opus]  📂 /Users/you/Developer/salesforce/salesforce-nexus
🌿 feature/my-branch 🔗 https://github.com/org/repo/tree/feature/my-branch
☁️  myDevSandbox  |  🔀 https://github.com/org/repo/pull/42
████████░░░░░░░░░░░░ 42%  |  💰 $0.08  |  ⏱️ 7m 3s  |  +156 -23
```

## What it shows

| Line | Content |
|------|---------|
| 1 | Model name + full project path (clickable in Warp) |
| 2 | Git branch + full branch URL (clickable in Warp) |
| 3 | Salesforce target org + PR link (or "no PR" / "no org") |
| 4 | Context usage bar + session cost + duration + lines added/removed |

## Prerequisites

- [jq](https://jqlang.github.io/jq/) - JSON parser (`brew install jq`)
- [gh](https://cli.github.com/) - GitHub CLI (`brew install gh`) - for PR links
- [sf](https://developer.salesforce.com/tools/salesforcecli) - Salesforce CLI - for org display

## Install

1. Make the script executable:

```bash
chmod +x .claude/statusline/statusline-command.sh
```

2. Add the status line to your **user** settings at `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "<path-to-repo>/.claude/statusline/statusline-command.sh"
  }
}
```

Replace `<path-to-repo>` with the absolute path to this repository, e.g.:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/you/Developer/salesforce/salesforce-nexus/.claude/statusline/statusline-command.sh"
  }
}
```

3. The status line appears at the bottom of Claude Code on your next interaction.

## Context bar colors

- 🟩 Green: < 50% context used
- 🟨 Yellow: 50-80% context used
- 🟥 Red: > 80% context used
