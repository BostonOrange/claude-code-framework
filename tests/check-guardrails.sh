#!/bin/bash
# Claude Code Framework — Guardrails Hook Unit Tests
# Tests the guardrails.sh hook with known commands and expected exit codes
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

# Ensure the hook is executable
chmod +x "$GUARDRAILS"

# ── Helper: run a test case ────────────────────────────────────

run_test() {
    local description="$1"
    local command="$2"
    local expected_exit="$3"

    TOTAL=$((TOTAL + 1))

    # Run the guardrails hook with the command as argument, suppress output
    bash "$GUARDRAILS" "$command" > /dev/null 2>&1
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
run_test "Git force push"               "git push --force origin main"        1
run_test "Git push -f"                  "git push -f origin main"             1
run_test "Git hard reset"               "git reset --hard HEAD~1"             1
run_test "Git clean -f"                 "git clean -fd"                       1
run_test "Docker push"                  "docker push myimage"                 1
run_test "Terraform apply"              "terraform apply"                     1
run_test "Terraform destroy"            "terraform destroy"                   1
run_test "Kubectl apply"                "kubectl apply -f deploy.yml"         1
run_test "Kubectl delete"               "kubectl delete pod mypod"            1
run_test "Vercel production deploy"     "vercel deploy --prod"                1
run_test "Database migration (prisma)"  "prisma db push"                      1
run_test "Database migration (alembic)" "alembic upgrade head"                1
echo ""

# ── Hard-blocked commands (exit 2) ─────────────────────────────

echo "Hard-blocked commands (should exit 2)..."
run_test "rm -rf /"                     "rm -rf /"                            2
run_test "rm -rf ~"                     "rm -rf ~"                            2
run_test "rm -rf \$HOME"               'rm -rf $HOME'                        2
run_test "rm -rf . (current dir)"       "rm -rf ."                            2
run_test "rm -rf ./"                    "rm -rf ./"                           2
echo ""

# ── Safe commands (exit 0) ─────────────────────────────────────

echo "Safe commands (should exit 0)..."
run_test "npm test"                     "npm test"                            0
run_test "git status"                   "git status"                          0
run_test "ls -la"                       "ls -la"                              0
run_test "Empty string"                 ""                                    0
run_test "git commit"                   "git commit -m 'test'"                0
run_test "cat file"                     "cat README.md"                       0
run_test "python test"                  "pytest tests/"                       0
run_test "git push (no force)"          "git push origin main"                0
run_test "rm single file"              "rm temp.txt"                          0
run_test "SF validate (not deploy)"     "sf project deploy validate"          0
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
