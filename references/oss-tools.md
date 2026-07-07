# OSS scanner wiring — invocation + gate mapping

Every tool below was verified to exist via `gh api` (recon 2026-07-07): repo, activity, license confirmed.
Each server may have **none** of these installed — that's fine. Detect presence (`command -v`), run what's there,
mark the rest `✗ absent` in the output, and fall back to static reasoning (`attack-taxonomy.md`). Never imply an
absent tool passed. `scripts/run_scanners.sh <target>` automates detection + invocation and prints a summary.

Two surfaces, two tool groups:
- **Tool-definition surface** → MCP-native scanners (§1–2). Point at a config/server.
- **Source surface** → clone the repo first, then general scanners (§3–6). Point at the cloned dir.

---

## 1. mcp-scan — PRIMARY engine (MCP-native) · Invariant Labs → Snyk · Apache-2.0
Repo: `snyk/agent-scan` (the former `invariantlabs-ai/mcp-scan`; the `mcp-scan` CLI/PyPI name still works). ~2.7k★, active.
It is the only tool purpose-built for this threat model — tool poisoning, injection in descriptions, cross-origin
escalation — and its **tool-pinning** (hashes tool defs, alerts on drift) is the one rug-pull signal nothing else produces.

```bash
# Static scan of a config (Mode B, or Mode A once you have the candidate's config):
uvx mcp-scan@latest scan <path-to-mcp-config.json> --json      # no install needed via uvx
#   or:  npx mcp-scan scan <config> --json   /   pipx run mcp-scan scan <config>

# Runtime enforcement for APPROVED long-lived servers (guardrails + logging):
uvx mcp-scan@latest proxy
```
**Gate:** any finding of category `tool_poisoning` / `prompt_injection` / `cross_origin`, or a **pin mismatch**
(rug pull) → **BLOCK**. Clean → advance to source scan. If `mcp-scan` can't reach the server to enumerate tools,
say so and lean on Step 3 static reading of the descriptions.

## 2. cisco-ai-defense/mcp-scanner — SECOND OPINION (MCP-native) · Cisco · Apache-2.0
~1k★, active. YARA + LLM-as-judge + Cisco AI Defense engines. Use to break ties when mcp-scan is ambiguous.
```bash
pip install mcp-scanner        # then run against a server URL/config
mcp-scanner --engine yara,llm <server-url-or-config>
```
**Gate:** any YARA or LLM-judge "malicious/injection" verdict → **BLOCK**.

## 3. semgrep — source SAST · Semgrep · LGPL-2.1
~15.8k★. Language-agnostic; reads the server's actual code for exec/network/exfil sinks.
```bash
semgrep scan --config auto --config p/security-audit --config p/secrets --json <cloned-repo>
```
**Gate:** `ERROR`-severity match in a network/exec/file sink → **BLOCK**; `WARNING` → **WARN**. Exit `1` = findings.
(Note: the archived `semgrep/mcp` *server wrapper* is NOT this — use the core `semgrep` CLI.)

## 4. trufflehog — verified secrets · Truffle Security · AGPL-3.0
~27k★. `--only-verified` live-checks credentials, so hits are actionable, not noise.
```bash
trufflehog git file://<cloned-repo> --only-verified --json
#   filesystem target:  trufflehog filesystem <cloned-repo> --only-verified --json
```
**Gate:** any **verified** secret / hardcoded key / exfil endpoint → **BLOCK**. Unverified → **WARN**.
(Interchangeable-ish: `gitleaks detect --source <repo>` for a fast unverified secret pass.)

## 5. guarddog — malicious-package heuristics · Datadog · Apache-2.0
~1.1k★. YARA rules for install-hooks, exfil, credential harvesting in npm/PyPI packages — the supply-chain layer.
```bash
guarddog npm scan <pkg>            # or:  guarddog npm verify <path-to-package.json>
guarddog pypi scan <pkg>          # or:  guarddog pypi verify <requirements.txt>
#   zero-install:  pipx run guarddog npm scan <pkg>
```
**Gate:** any **HIGH** correlated finding (capability + threat indicator in one file) → **BLOCK**; medium → **WARN**.

## 6. osv-scanner — known-CVE deps · Google / OSV.dev · Apache-2.0
~10.6k★. Deterministic dependency vuln scan.
```bash
osv-scanner scan source -r <cloned-repo>      # or:  osv-scanner --lockfile <lockfile>
```
**Gate:** exit `1` = vulns. `CRITICAL`/`HIGH` reachable dep → **WARN** (escalate to BLOCK per policy); none → pass.
(`trivy fs --scanners vuln,secret,misconfig <repo>` covers deps+secrets+IaC in one binary if you prefer.)

---

## Deep / optional (only for shortlisted servers exposing LLM-facing tools)
- **NVIDIA/garak** (~8.4k★, Apache-2.0) — *actively fires* injection/jailbreak payloads rather than static-matching:
  `garak --model_type <rest/bridge> --probes promptinject,latentinjection`. High hit-rate → BLOCK. Slow; shortlist only.
- **protectai/llm-guard** (MIT) — cheap `PromptInjection` DeBERTa classifier to pre-screen every tool-description
  string before the expensive garak stage. Good fast filter.

## Runtime enforcement (post-approval, catches drift live)
- **trailofbits/mcp-context-protector** (~220★, Apache-2.0) — wraps a server with trust-on-first-use pinning of its
  instructions + tool descriptions: `mcp-context-protector -- <server-launch-command>`. Recommend it for anything
  APPROVED and long-lived so a later rug pull trips a pin break instead of silently shipping.

## Provenance (no install — network/registry check)
- Official **MCP Registry** — reverse-DNS namespace verified via GitHub OAuth / DNS TXT. Check whether the server is
  listed under a namespace that matches the vendor it claims. Ownership proof ≠ safety, but absence/mismatch is a flag.

## De-prioritized / avoid (verified but weak — don't wire in)
`protectai/rebuff` (ARCHIVED 2024), `semgrep/mcp` wrapper (ARCHIVED — use core semgrep), and sub-10★ MCP scanners
(`SecScanMCP`, `mcpshield`, `eSentire-Labs/mcp-scanner`) — real but unproven; reference only.

---

## Layering summary
1. **mcp-scan** (+ cisco as tiebreak) on the tool-definition surface → BLOCK on poisoning/injection/pin-mismatch.
2. Clone repo → **guarddog** + **trufflehog** + **semgrep** + **osv-scanner** on the source surface → BLOCK on
   verified secret / HIGH malicious-package / exec-sink ERROR.
3. **garak/llm-guard** only for shortlisted LLM-facing servers.
4. APPROVE only when *both* surfaces were actually covered and clean. Recommend **mcp-context-protector** on every APPROVE.
