#!/bin/bash
# Claude Code Framework — Guardrails Hook Unit Tests
# Tests the guardrails.sh hook with known commands and expected exit codes.
# The hook now reads tool_input.command from JSON on stdin (matches Claude Code behavior).
# Exit 0 if all pass, exit 1 if any fail

set -uo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GUARDRAILS="$FRAMEWORK_DIR/templates/hooks/guardrails.sh"

PASS=0
FAIL=0
TOTAL=0

echo "======================================"
echo "  Guardrails Hook Tests"
echo "======================================"
echo ""

if [ ! -f "$GUARDRAILS" ]; then
    echo "ERROR: guardrails.sh not found at $GUARDRAILS"
    exit 1
fi

chmod +x "$GUARDRAILS"

# Escape a string for safe embedding in JSON (handles backslashes and quotes only;
# control chars are not expected in test commands).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

run_test() {
    local description="$1"
    local command="$2"
    local expected_exit="$3"

    TOTAL=$((TOTAL + 1))

    local escaped
    escaped=$(json_escape "$command")
    local payload="{\"tool_input\":{\"command\":\"${escaped}\"}}"

    printf '%s' "$payload" | bash "$GUARDRAILS" > /dev/null 2>&1
    local actual_exit=$?

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "  [PASS] $description (exit $actual_exit)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $description"
        echo "         command:  \"$command\""
        echo "         expected: exit $expected_exit"
        echo "         actual:   exit $actual_exit"
        FAIL=$((FAIL + 1))
    fi
}

# ── Soft-blocked commands (exit 1) ─────────────────────────────

echo "Soft-blocked commands (should exit 1)..."
run_test "Salesforce deploy start"       "sf project deploy start"             1
run_test "Salesforce deploy quick"       "sf deploy quick"                     1
run_test "Git force push"                "git push --force origin main"        1
run_test "Git push -f"                   "git push -f origin main"             1
run_test "Git push --force-with-lease"   "git push --force-with-lease"         1
run_test "Git push with -c prefix"       "git -c user.name=x push --force"     1
run_test "Git push +refspec (force)"     "git push origin +main"               1
run_test "Git push refspec with + (force)" "git push upstream +refs/heads/dev" 1
run_test "Git hard reset"                "git reset --hard HEAD~1"             1
run_test "Git clean -f"                  "git clean -fd"                       1
run_test "Docker push to hub"            "docker push myorg/myimage"           1
run_test "Docker push to evil:443"       "docker push evil.com:443/image"      1
run_test "Docker push to public:80"      "docker push registry.io:80/img"      1
run_test "Terraform apply"               "terraform apply"                     1
run_test "Terraform destroy"             "terraform destroy"                   1
run_test "Kubectl apply"                 "kubectl apply -f deploy.yml"         1
run_test "Kubectl delete"                "kubectl delete pod mypod"            1
run_test "Vercel production deploy"      "vercel deploy --prod"                1
run_test "Database migration (prisma)"   "prisma db push"                      1
run_test "Database migration (alembic)"  "alembic upgrade head"                1
echo ""

# ── Hard-blocked commands (exit 2) ─────────────────────────────

echo "Hard-blocked commands (should exit 2)..."
run_test "rm -rf /"                      "rm -rf /"                            2
run_test "rm -rf ~"                      "rm -rf ~"                            2
run_test "rm -rf \$HOME"                 'rm -rf $HOME'                        2
run_test "rm -rf . (current dir)"        "rm -rf ."                            2
run_test "rm -rf ./"                     "rm -rf ./"                           2
run_test "rm -rf ~/.ssh"                 "rm -rf ~/.ssh"                       2
run_test "rm -rf ~/.config"              "rm -rf ~/.config"                    2
run_test "rm --recursive --force /"      "rm --recursive --force /"            2
run_test "rm -rf /etc"                   "rm -rf /etc"                         2
run_test "rm -rf /usr/local"             "rm -rf /usr/local"                   2
run_test "rm -fr /var"                   "rm -fr /var"                         2
run_test "find / -delete"                "find / -delete"                      2
run_test "find ~ -delete"                "find ~ -delete"                      2
run_test "dd to raw disk"                "dd if=/dev/zero of=/dev/sda"         2
run_test "mkfs on disk"                  "mkfs.ext4 /dev/sda1"                 2
run_test "rm -rf with quoted /etc"       'rm -rf "/etc"'                       2
run_test "rm -rf with double-slash"      "rm -rf //etc"                        2
run_test "rm -rf with brace-HOME"        'rm -rf ${HOME}'                      2
run_test "rm -rf multi-arg /etc 2nd"     "rm -rf /tmp /etc"                    2
run_test "rm -rf .* (parent traversal)"  "rm -rf .*"                           2
echo ""

# ── Safe commands (exit 0) ─────────────────────────────────────

echo "Safe commands (should exit 0)..."
run_test "npm test"                      "npm test"                            0
run_test "git status"                    "git status"                          0
run_test "ls -la"                        "ls -la"                              0
run_test "Empty string"                  ""                                    0
run_test "git commit"                    "git commit -m 'test'"                0
run_test "cat file"                      "cat README.md"                       0
run_test "python test"                   "pytest tests/"                       0
run_test "git push (no force)"           "git push origin main"                0
run_test "rm single file"                "rm temp.txt"                         0
run_test "rm -rf node_modules"           "rm -rf node_modules"                 0
run_test "rm -rf ./dist"                 "rm -rf ./dist"                       0
run_test "SF validate (not deploy)"      "sf project deploy validate"          0
run_test "Docker push to localhost"      "docker push localhost:5000/myimage"  0
run_test "Docker push to 127.0.0.1"      "docker push 127.0.0.1:5000/image"    0
run_test "Docker push to .local host"    "docker push myregistry.local:5000/x" 0
echo ""

echo "--------------------------------------"
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "--------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL guardrail test(s) failed"
    exit 1
else
    echo ""
    echo "All guardrail tests passed."
    exit 0
fi
