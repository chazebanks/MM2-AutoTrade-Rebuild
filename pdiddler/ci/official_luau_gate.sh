#!/usr/bin/env bash
# Official Luau CLI gate. Offline only; never loads Roblox or Delta.
set -euo pipefail
cd "$(dirname "$0")/../.."

for command in luau-compile luau-analyze; do
    command -v "$command" >/dev/null || { echo "Missing official $command" >&2; exit 1; }
done

# This initial allowlist includes real checked-in sources. Do not glob all
# archived MM2 scripts: they are not clean static-analysis baselines yet.
syntax_files=(
    pdiddler/core/health.lua
    pdiddler/loader.lua
    pdiddler/test_runner.lua
    pdiddler/pdiddler1.lua
    pdiddler/pdiddler2.lua
    values/mm2values.lua
)
analysis_files=(
    pdiddler/core/health.lua
    values/mm2values.lua
)

for file in "${syntax_files[@]}"; do
    echo "[Luau compile] $file"
    luau-compile --binary "$file" >/dev/null
done
for file in "${analysis_files[@]}"; do
    echo "[Luau analyze] $file"
    luau-analyze "$file"
done

# Negative controls ensure both checks genuinely reject broken input.
# They are throwaway fixtures, not modifications to the user's scripts.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'local broken =\n' >"$tmp/syntax_error.luau"
if luau-compile --binary "$tmp/syntax_error.luau" >"$tmp/compiler.log" 2>&1; then
    echo "[FAIL] Luau compiler accepted an invalid source" >&2
    exit 1
fi
printf '%s\n' '--!strict' 'local invalid: number = "wrong"' >"$tmp/type_error.luau"
if luau-analyze "$tmp/type_error.luau" >"$tmp/analyzer.log" 2>&1; then
    echo "[FAIL] Luau analyzer accepted a deliberate type mismatch" >&2
    exit 1
fi
echo "[PASS] Luau compiler and analyzer rejected invalid fixtures"
echo "[PASS] Checked ${#syntax_files[@]} real source files for syntax and ${#analysis_files[@]} for static analysis"
