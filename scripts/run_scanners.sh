#!/usr/bin/env bash
# mcp-vet — scanner orchestrator.
# Detects which OSS security scanners are installed, runs the present ones against a target,
# and prints a machine-readable summary the skill folds into an APPROVE/WARN/BLOCK gate.
# Absent tools are reported as "absent" — never as a pass. This is a signal collector, not the judge:
# the skill (SKILL.md Step 3–4) synthesizes these results with static reasoning into the final verdict.
#
# Usage:
#   run_scanners.sh --config <mcp-config.json>            # tool-definition surface only
#   run_scanners.sh --source <cloned-repo-dir>            # source/supply-chain surface only
#   run_scanners.sh --config <cfg> --source <dir> \
#                   [--npm <pkg> | --pypi <pkg>]          # both surfaces (+ package heuristics)
#
# Nothing here decides BLOCK/WARN/APPROVE — it emits per-tool status + findings for the model to interpret.

set -uo pipefail

CONFIG=""; SOURCE=""; NPM_PKG=""; PYPI_PKG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2;;
    --source) SOURCE="$2"; shift 2;;
    --npm)    NPM_PKG="$2"; shift 2;;
    --pypi)   PYPI_PKG="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; shift;;
  esac
done

has() { command -v "$1" >/dev/null 2>&1; }
# uvx/npx/pipx let us run mcp-scan & guarddog with zero install — treat those runners as "present" too.
has_runner() { has "$1"; }

section() { printf '\n=== %s ===\n' "$1"; }
status()  { printf '[%s] %s\n' "$1" "$2"; }   # $1 = PRESENT|ABSENT|RAN|SKIP

printf '### mcp-vet scanner run — %s\n' "$(uname -s)"
printf 'config=%s source=%s npm=%s pypi=%s\n' "${CONFIG:-none}" "${SOURCE:-none}" "${NPM_PKG:-none}" "${PYPI_PKG:-none}"

########################################
# Surface 1 — tool-definition (MCP-native)
########################################
if [[ -n "$CONFIG" ]]; then
  section "TOOL-DEFINITION SURFACE (config: $CONFIG)"

  # PRIMARY: mcp-scan (Invariant→Snyk). Prefer a native install; else uvx/npx/pipx.
  if has mcp-scan; then
    status RAN "mcp-scan scan"; mcp-scan scan "$CONFIG" 2>&1 || true
  elif has_runner uvx; then
    status RAN "uvx mcp-scan@latest scan"; uvx mcp-scan@latest scan "$CONFIG" 2>&1 || true
  elif has_runner npx; then
    status RAN "npx mcp-scan scan"; npx --yes mcp-scan scan "$CONFIG" 2>&1 || true
  else
    status ABSENT "mcp-scan (PRIMARY tool-poisoning/injection/pin engine) — no mcp-scan/uvx/npx. Fall back to static description review."
  fi

  # SECOND OPINION: cisco mcp-scanner
  if has mcp-scanner; then
    status RAN "cisco mcp-scanner"; mcp-scanner --engine yara,llm "$CONFIG" 2>&1 || true
  else
    status ABSENT "cisco mcp-scanner (second opinion)"
  fi
else
  section "TOOL-DEFINITION SURFACE"
  status SKIP "no --config given; enumerate the server's tools and review descriptions statically (attack-taxonomy.md)"
fi

########################################
# Surface 2 — source & supply chain
########################################
if [[ -n "$SOURCE" ]]; then
  section "SOURCE SURFACE (repo: $SOURCE)"

  # Secrets — verified only (actionable)
  if has trufflehog; then
    status RAN "trufflehog --only-verified"; trufflehog filesystem "$SOURCE" --only-verified --json 2>/dev/null || true
  elif has gitleaks; then
    status RAN "gitleaks (unverified fallback)"; gitleaks detect --source "$SOURCE" --no-banner 2>&1 || true
  else
    status ABSENT "trufflehog/gitleaks (secret scan) — grep source manually for hardcoded keys / exfil URLs"
  fi

  # SAST
  if has semgrep; then
    status RAN "semgrep security-audit+secrets"
    semgrep scan --config auto --config p/security-audit --config p/secrets --error --quiet "$SOURCE" 2>&1 || true
  else
    status ABSENT "semgrep (SAST) — read code for exec/network/exfil sinks manually"
  fi

  # Known-CVE deps
  if has osv-scanner; then
    status RAN "osv-scanner"; osv-scanner scan source -r "$SOURCE" 2>&1 || true
  elif has trivy; then
    status RAN "trivy fs"; trivy fs --scanners vuln,secret,misconfig --quiet "$SOURCE" 2>&1 || true
  else
    status ABSENT "osv-scanner/trivy (dependency CVEs)"
  fi
else
  section "SOURCE SURFACE"
  status SKIP "no --source given; clone the server's repo to scan its code (SKILL.md Step 2)"
fi

########################################
# Package heuristics — malicious npm/PyPI (guarddog)
########################################
section "SUPPLY-CHAIN / PACKAGE HEURISTICS"
run_guarddog() { # $1=ecosystem npm|pypi  $2=pkg
  if has guarddog; then status RAN "guarddog $1 scan $2"; guarddog "$1" scan "$2" 2>&1 || true
  elif has_runner pipx; then status RAN "pipx run guarddog $1 scan $2"; pipx run guarddog "$1" scan "$2" 2>&1 || true
  else status ABSENT "guarddog ($1 malicious-package heuristics)"; fi
}
[[ -n "$NPM_PKG"  ]] && run_guarddog npm  "$NPM_PKG"
[[ -n "$PYPI_PKG" ]] && run_guarddog pypi "$PYPI_PKG"
[[ -z "$NPM_PKG$PYPI_PKG" ]] && status SKIP "no --npm/--pypi package given; pass one to run guarddog"

########################################
# Coverage summary — be honest about gaps
########################################
section "COVERAGE SUMMARY"
printf 'tool-definition surface: %s\n' "$([[ -n "$CONFIG" ]] && echo attempted || echo NOT-COVERED)"
printf 'source surface:          %s\n' "$([[ -n "$SOURCE" ]] && echo attempted || echo NOT-COVERED)"
printf 'package heuristics:       %s\n' "$([[ -n "$NPM_PKG$PYPI_PKG" ]] && echo attempted || echo NOT-COVERED)"
printf '\nReminder: ABSENT ≠ pass. Any NOT-COVERED surface lowers confidence — reflect it in the gate line.\n'
