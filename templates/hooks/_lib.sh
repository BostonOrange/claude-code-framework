#!/bin/bash
# Claude Code Framework — Shared Hook Library
# Sourced by hooks that need to parse stdin JSON (Claude Code's hook input format).
# Do not wire this file as a hook itself.

# read_tool_input_field <field-path>
#
# Reads a JSON object from stdin and extracts a field from tool_input.
# Example: read_tool_input_field file_path
# Prints the field value (empty string if not present or parse fails).
# Uses jq when available, falls back to python3, else exits non-zero.
#
# Returns:
#   0 — field extracted (or empty)
#   2 — no JSON parser available (neither jq nor python3)
read_tool_input_field() {
    local field="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -r ".tool_input.${field} // empty" 2>/dev/null
        return 0
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('${field}', ''))
except Exception:
    pass
" 2>/dev/null
        return 0
    else
        return 2
    fi
}
