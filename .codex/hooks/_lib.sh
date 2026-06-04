#!/bin/bash
# Framework Repo — Shared Hook Library
# Sourced by hooks that need to parse stdin JSON.

# read_tool_input_field <field-path>
# Prints tool_input.<field> from stdin JSON. Exits 2 if no parser available.
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
