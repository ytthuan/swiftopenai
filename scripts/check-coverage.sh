#!/usr/bin/env bash
# =============================================================================
# scripts/check-coverage.sh
# SwiftOpenAI — line-coverage gate using SwiftPM LLVM JSON output.
#
# Usage:
#   bash scripts/check-coverage.sh --threshold 62 [--tolerance 0.5] \
#        [--coverage-json PATH] [--summary-out PATH]
#
# Inputs:
#   --threshold N          Required. Integer 0-100. Minimum acceptable % coverage.
#   --tolerance T          Optional. Float, default 0.5. Allowed slack in percent
#                          points. The effective floor = threshold - tolerance.
#   --coverage-json PATH   Optional. Path to the LLVM coverage JSON file produced
#                          by `swift test --enable-code-coverage`. If omitted the
#                          path is discovered via `swift test --show-codecov-path`.
#   --summary-out PATH     Optional. Append a Markdown summary table to this file
#                          (use $GITHUB_STEP_SUMMARY in CI).
#   --help                 Print this help and exit 0.
#
# Exit codes:
#   0  Coverage is at or above the effective floor (threshold - tolerance).
#   1  Coverage is below the effective floor.
#   2  Coverage JSON file not found or not readable.
#   3  Required dependency (jq) is not installed.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# usage
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ---------------------------------------------------------------------------
# defaults
# ---------------------------------------------------------------------------
THRESHOLD=""
TOLERANCE="0.5"
COVERAGE_JSON=""
SUMMARY_OUT=""

# ---------------------------------------------------------------------------
# parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold)
            THRESHOLD="$2"; shift 2 ;;
        --tolerance)
            TOLERANCE="$2"; shift 2 ;;
        --coverage-json)
            COVERAGE_JSON="$2"; shift 2 ;;
        --summary-out)
            SUMMARY_OUT="$2"; shift 2 ;;
        --help|-h)
            usage ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1 ;;
    esac
done

if [[ -z "$THRESHOLD" ]]; then
    echo "Error: --threshold is required." >&2
    echo "Run with --help for usage." >&2
    exit 1
fi

# Validate threshold is an integer 0–100
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( THRESHOLD < 0 || THRESHOLD > 100 )); then
    echo "Error: --threshold must be an integer between 0 and 100." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# check jq
# ---------------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required but not installed." >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Linux:  sudo apt-get install -y jq   (Debian/Ubuntu)" >&2
    echo "          sudo yum install -y jq        (RHEL/CentOS)" >&2
    exit 3
fi

# ---------------------------------------------------------------------------
# discover coverage JSON if not supplied
# ---------------------------------------------------------------------------
if [[ -z "$COVERAGE_JSON" ]]; then
    COVERAGE_JSON="$(swift test --show-codecov-path 2>/dev/null || true)"
fi

if [[ -z "$COVERAGE_JSON" ]] || [[ ! -f "$COVERAGE_JSON" ]]; then
    echo "Coverage JSON not found at '${COVERAGE_JSON:-<empty>}'." >&2
    echo "Run 'swift test --enable-code-coverage' first, then re-run this script." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# parse and compute weighted coverage over Sources/SwiftOpenAI/ files only
# ---------------------------------------------------------------------------
# Schema: top-level .data[] array; each element has .files[] array;
# each file has .filename (string), .summary.lines.{count, covered, percent}.
# We filter to files whose path contains "Sources/SwiftOpenAI/"
# and exclude Tests/, Examples/, ExampleApp/, .build/.

RESULT="$(jq -r '
  [
    .data[]
    | .files[]
    | select(
        (.filename | contains("Sources/SwiftOpenAI/"))
        and (.filename | contains("Tests/") | not)
        and (.filename | contains("Examples/") | not)
        and (.filename | contains("ExampleApp/") | not)
        and (.filename | contains(".build/") | not)
      )
    | { count: .summary.lines.count, covered: .summary.lines.covered }
  ]
  | { total_count: (map(.count) | add // 0),
      total_covered: (map(.covered) | add // 0) }
  | . + {
      pct: (if .total_count == 0 then 0.0
            else (.total_covered / .total_count * 100.0)
            end)
    }
  | "\(.total_covered) \(.total_count) \(.pct)"
' "$COVERAGE_JSON")"

COVERED="$(echo "$RESULT" | awk '{print $1}')"
TOTAL="$(echo "$RESULT" | awk '{print $2}')"
PCT="$(echo "$RESULT" | awk '{print $3}')"

# Compute effective floor:  threshold - tolerance  (using awk for float math)
FLOOR="$(awk -v t="$THRESHOLD" -v tol="$TOLERANCE" 'BEGIN { printf "%.1f", t - tol }')"

# Format display values
PCT_FMT="$(awk -v p="$PCT" 'BEGIN { printf "%.1f", p }')"
THRESHOLD_FMT="$(awk -v t="$THRESHOLD" 'BEGIN { printf "%.1f", t }')"
TOLERANCE_FMT="$(awk -v tol="$TOLERANCE" 'BEGIN { printf "%.1f", tol }')"

echo "Coverage:       ${PCT_FMT}% (${COVERED}/${TOTAL} lines)"
echo "Threshold:      ${THRESHOLD_FMT}% (tolerance ${TOLERANCE_FMT}%)"
echo "Effective floor: ${FLOOR}%"

# Determine pass/fail
PASS="$(awk -v p="$PCT" -v f="$FLOOR" 'BEGIN { print (p >= f) ? "1" : "0" }')"

if [[ "$PASS" == "1" ]]; then
    STATUS="✅ PASS"
    echo "Result: ${STATUS} (${PCT_FMT}% >= ${FLOOR}%)"
else
    STATUS="❌ FAIL"
    echo "Result: ${STATUS} (${PCT_FMT}% < ${FLOOR}%)" >&2
fi

# ---------------------------------------------------------------------------
# optional Markdown summary for $GITHUB_STEP_SUMMARY
# ---------------------------------------------------------------------------
if [[ -n "$SUMMARY_OUT" ]]; then
    {
        echo ""
        echo "## Coverage Report"
        echo ""
        echo "| Metric | Value |"
        echo "|---|---|"
        echo "| Total line coverage | ${PCT_FMT}% |"
        echo "| Lines covered | ${COVERED} |"
        echo "| Lines total | ${TOTAL} |"
        echo "| Threshold | ${THRESHOLD_FMT}% |"
        echo "| Tolerance | ${TOLERANCE_FMT}% |"
        echo "| Effective floor | ${FLOOR}% |"
        echo "| Status | ${STATUS} |"
    } >> "$SUMMARY_OUT"
    echo "Markdown summary appended to: ${SUMMARY_OUT}"
fi

# ---------------------------------------------------------------------------
# exit with status
# ---------------------------------------------------------------------------
if [[ "$PASS" == "1" ]]; then
    exit 0
else
    exit 1
fi
