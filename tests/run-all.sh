#!/bin/bash
# Claude Code Framework — Master Test Runner
# Runs all check-*.sh test scripts and reports overall results
# Exit 0 if all passed, exit 1 if any failed

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

TOTAL=0
PASSED=0
FAILED=0
FAILED_TESTS=""

echo "============================================"
echo "  Claude Code Framework — Test Suite"
echo "============================================"
echo ""

# Collect all check-*.sh scripts in this directory
SCRIPTS=$(find "$TESTS_DIR" -maxdepth 1 -name "check-*.sh" -type f | sort)

if [ -z "$SCRIPTS" ]; then
    echo "ERROR: No test scripts found in $TESTS_DIR"
    exit 1
fi

for script in $SCRIPTS; do
    test_name=$(basename "$script" .sh)
    TOTAL=$((TOTAL + 1))

    echo "--------------------------------------------"
    echo "  Running: $test_name"
    echo "--------------------------------------------"
    echo ""

    # Run the test script, capture exit code
    if bash "$script"; then
        PASSED=$((PASSED + 1))
        RESULT="PASS"
    else
        FAILED=$((FAILED + 1))
        FAILED_TESTS="$FAILED_TESTS $test_name"
        RESULT="FAIL"
    fi

    echo ""
done

# ── Summary ────────────────────────────────────────────────────

echo "============================================"
echo "  Test Suite Summary"
echo "============================================"
echo ""
echo "  Total:  $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

# Print table of results
echo "  +----------------------------+--------+"
echo "  | Test                       | Result |"
echo "  +----------------------------+--------+"

for script in $SCRIPTS; do
    test_name=$(basename "$script" .sh)
    # Pad name to 26 chars
    padded_name=$(printf "%-26s" "$test_name")

    # Check if this test was in the failed list
    if echo "$FAILED_TESTS" | grep -q "$test_name"; then
        echo "  | $padded_name | FAIL   |"
    else
        echo "  | $padded_name | PASS   |"
    fi
done

echo "  +----------------------------+--------+"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "RESULT: FAILED ($FAILED of $TOTAL tests failed)"
    echo "Failed tests:$FAILED_TESTS"
    exit 1
else
    echo "RESULT: ALL TESTS PASSED ($PASSED of $TOTAL)"
    exit 0
fi
