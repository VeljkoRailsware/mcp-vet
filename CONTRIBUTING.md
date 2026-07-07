# Contributing to mcp-vet

Thanks for helping harden the MCP ecosystem. `mcp-vet` is a detection tool, so contributions that add real
signal — a new attack class, a new scanner, a sharper heuristic, a regression test — are especially welcome.

## Ground rules

- **Every claim needs a source.** This is a security tool; unsupported assertions erode trust. New attack classes,
  incidents, or tool recommendations must cite an authoritative source, added to [`references/sources.md`](references/sources.md)
  (prefer primary: the MCP spec, Trail of Bits, Invariant Labs/Snyk, OWASP, NSA, Datadog, vendor advisories).
- **No fabricated findings, ever.** The skill's core promise is that an absent scanner is reported absent, never as
  a pass. Any change must preserve that honesty contract (see the "Honesty rules" section of `SKILL.md`).
- **Don't add a scanner you haven't verified.** Confirm the repo exists and is maintained (`gh api repos/OWNER/REPO`),
  note stars + last-push + license, and prefer high-authority maintainers.

## How to add…

### A new attack class
1. Add it to [`references/attack-taxonomy.md`](references/attack-taxonomy.md): where it hides, concrete red-flag
   patterns, and the default verdict. Add a row to the triage table.
2. If it changes the gate, update the rubric in [`SKILL.md`](SKILL.md) and the condensed rubric in each
   [`adapters/`](adapters/) file (Cursor, VS Code, Codex — keep them in sync).
3. Add a test case to [`evals/evals.json`](evals/evals.json) that would fail without the change.

### A new scanner
1. Wire detection + invocation into [`scripts/run_scanners.sh`](scripts/run_scanners.sh) behind a `command -v`
   check, with graceful skip when absent. It must degrade, never hard-fail.
2. Document the exact CLI + how its exit code / output maps to APPROVE/WARN/BLOCK in
   [`references/oss-tools.md`](references/oss-tools.md).
3. Keep the two-surface model intact: is it a **tool-definition** scanner or a **source/supply-chain** scanner?

### A test case
Add to [`evals/evals.json`](evals/evals.json) with a `prompt`, `expected_output`, and `assertions`. Good cases are
adversarial — a malicious server that a naive check would wave through, or a benign one a trigger-happy check would
wrongly block. Both false-negatives and false-positives matter.

## Before you open a PR

```bash
# Shell script must stay valid + shellcheck-clean:
bash -n scripts/run_scanners.sh
shellcheck scripts/run_scanners.sh      # if installed

# JSON must parse:
python3 -m json.tool evals/evals.json >/dev/null

# Sanity-run the scanner with no scanners installed (should report coverage honestly, not crash):
bash scripts/run_scanners.sh --config /nonexistent.json || true
```

Keep `SKILL.md` under ~500 lines (progressive disclosure — depth belongs in `references/`). Keep the three adapters
faithful to the skill's rubric; if you change the gate logic in one place, change it everywhere.

## Reporting a malicious MCP server

If you've found a real malicious server in the wild, **report it to the registry/package host first** (npm, PyPI,
the MCP Registry) so it gets taken down. A sanitized write-up is welcome here as a new taxonomy example or eval case
once it's public — but takedown comes before disclosure.

## License

By contributing you agree your work is licensed under the repository's [MIT License](LICENSE).
