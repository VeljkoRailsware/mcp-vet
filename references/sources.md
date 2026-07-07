# Sources — authority-tier citations

Every claim in this skill traces to a Tier-1/2 source below (research 2026-07-07). Kept for audit/defense of verdicts.

## Attack taxonomy & vetting methodology
- **Trail of Bits — "Jumping the line: how MCP servers can attack you before you ever use them"** (2025-04-21) — line
  jumping; why vetting must be static/pre-invocation. https://blog.trailofbits.com/2025/04/21/jumping-the-line-how-mcp-servers-can-attack-you-before-you-ever-use-them/
- **Invariant Labs — "MCP Security Notification: Tool Poisoning Attacks"** — coined "tool poisoning" (TPA); cross-server
  shadowing. https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks
- **Invariant Labs — "Introducing MCP-Scan"** + docs — the primary scanner, scan vs proxy modes, tool pinning.
  https://invariantlabs.ai/blog/introducing-mcp-scan · https://invariantlabs-ai.github.io/docs/mcp-scan/
- **Simon Willison — the "lethal trifecta"** — private data + untrusted content + external comms = exfil precondition.
- **Original methodology article (skill brief):** Tim Schipper, "How to vet an MCP server" — 6-check ~10-min checklist,
  count-the-verbs, version pinning, credential scoping, architectural segregation. https://tim-schipper.nl/en/blog/how-to-vet-an-mcp-server

## Standards / framework authorities
- **Official MCP spec — Security Best Practices** — token passthrough prohibition, least-privilege scopes, allowlists,
  isolation, logging. https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices
- **Official MCP Registry** — reverse-DNS namespace verification (GitHub OAuth / DNS TXT); Anthropic/GitHub/Microsoft/
  PulseMCP-backed; preview Sept 2025. https://modelcontextprotocol.io/registry/about
- **OWASP** — MCP Top 10 (https://owasp.org/www-project-mcp-top-10/), LLM Top 10 2025 incl. LLM06 Excessive Agency
  (https://genai.owasp.org/llm-top-10/), Top 10 for Agentic Applications.
- **NSA CSI — Model Context Protocol** — identity/consent/least-privilege, token handling, isolation, logging.
- **Microsoft** — "Protecting against indirect prompt injection attacks in MCP." · **Red Hat** — MCP security risks & controls.

## Ground-truth incident: postmark-mcp (first in-the-wild malicious MCP)
- **Postmark official advisory** — package was never official; legit Postmark services unaffected.
  https://postmarkapp.com/blog/information-regarding-malicious-postmark-mcp-package
- **Snyk** — harvests emails; remediation (uninstall, rotate tokens + downstream creds).
  https://snyk.io/blog/malicious-mcp-server-on-npm-postmark-mcp-harvests-emails/
- **The Hacker News** (2025-09) — 15 clean releases; backdoor v1.0.16 (pub. 2025-09-17); BCC to phan@giftshop[.]club;
  1,643 downloads. https://thehackernews.com/2025/09/first-malicious-mcp-server-found.html
- **Semgrep** — "So the first malicious MCP server has been found on npm…" — what it means for MCP security.

## OSS scanners (all confirmed via `gh api`, 2026-07-07)
snyk/agent-scan (was invariantlabs-ai/mcp-scan) · cisco-ai-defense/mcp-scanner · trailofbits/mcp-context-protector ·
DataDog/guarddog · semgrep/semgrep · trufflesecurity/trufflehog · gitleaks/gitleaks · google/osv-scanner ·
aquasecurity/trivy · NVIDIA/garak · protectai/llm-guard. Archived/avoid: protectai/rebuff, semgrep/mcp wrapper.
