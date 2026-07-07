# mcp-vet 🐕‍🦺

**A security "hound dog" that vets MCP (Model Context Protocol) servers before you trust them — and audits the ones you already run — then gives you a terse `APPROVE` / `WARN` / `BLOCK` decision with the reasons.**

An MCP server runs as the **most credentialed process in the room**: your agent hands it your tokens and executes whatever its tools describe. A malicious server doesn't need an exploit — it just needs a convincing tool *description*, because the model reads and obeys tool descriptions **before any tool is ever called**. That's not hypothetical: in September 2025 a malicious npm package impersonating a well-known transactional-email vendor ran 15 clean releases, then shipped a one-line backdoor in a later version that BCC'd every email — password resets, MFA codes, invoices — to an attacker's domain. ~1,600 installs later, it became the [first malicious MCP server found in the wild](https://thehackernews.com/2025/09/first-malicious-mcp-server-found.html).

`mcp-vet` is a portable instruction bundle + scanner-orchestration script that catches this class of thing. It works in **Claude Code, Cursor, VS Code (Copilot), and OpenAI Codex** — anywhere an agent can add an MCP server.

---

## What it actually does

Give it a GitHub URL, an npm/PyPI package, a raw config snippet, or point it at your existing MCP config, and it runs a 5-step pipeline across the **two surfaces where malice hides**:

- **Tool-definition surface** — the `tools/list` descriptions your model ingests. Home of tool poisoning, line jumping, and cross-server shadowing. *Invisible to source-code scanners.*
- **Source / supply-chain surface** — the actual code and dependencies. Home of exfil endpoints, hardcoded credentials, install-hook malware, and rug-pull diffs. *Invisible to description scanners.*

That incident proves you need both: the package's description was clean; the exfil was one line of **code**. Skip a surface and you miss half the threat.

It layers **real open-source scanners** when they're installed (and degrades honestly to static reasoning when they aren't — an absent scanner is reported as absent, never as a pass):

| Layer | Tool | Catches |
|---|---|---|
| Tool-definitions (primary) | [`mcp-scan`](https://github.com/snyk/agent-scan) (Invariant Labs → Snyk) | tool poisoning, injection, **rug-pull drift** (tool-def hashing) |
| Tool-definitions (2nd opinion) | [`cisco-ai-defense/mcp-scanner`](https://github.com/cisco-ai-defense/mcp-scanner) | YARA + LLM-judge verdicts |
| Source SAST | [`semgrep`](https://github.com/semgrep/semgrep) | exec / network / exfil sinks |
| Secrets | [`trufflehog --only-verified`](https://github.com/trufflesecurity/trufflehog) | live-verified hardcoded creds / exfil URLs |
| Malicious packages | [`guarddog`](https://github.com/DataDog/guarddog) (Datadog) | install-hooks, credential harvesting |
| Dependency CVEs | [`osv-scanner`](https://github.com/google/osv-scanner) (Google) | known-vulnerable deps |
| Runtime (post-approval) | [`mcp-context-protector`](https://github.com/trailofbits/mcp-context-protector) (Trail of Bits) | trust-on-first-use pinning; catches drift live |

## The threat taxonomy it gates on

Every finding maps to a named, documented attack class (full detail in [`references/attack-taxonomy.md`](references/attack-taxonomy.md)):

| Attack | What it is | Typical verdict |
|---|---|---|
| **Tool poisoning** | Hidden instructions in a tool description the model executes silently | 🛑 BLOCK |
| **Line jumping** | The server attacks via description metadata *before* any tool call | 🛑 BLOCK |
| **Tool / cross-server shadowing** | One server's description hijacks how a *different, trusted* server behaves | 🛑 BLOCK |
| **Rug pull / capability drift** | A trusted server changes behavior after install (clean for 15 releases, then a backdoor) | 🛑 BLOCK |
| **Supply-chain impersonation** | A legit-sounding name not published by the vendor it evokes | 🛑 BLOCK |
| **Token passthrough / credential theft** | Accepts or exfiltrates secrets never issued for it | 🛑 BLOCK |
| **Confused deputy** | Abuses its privileged position / OAuth beyond user intent | ⚠️ WARN |
| **Excessive agency** | Capabilities far beyond stated purpose ("count the verbs") | ⚠️ WARN |
| **Lethal trifecta** | Private data + untrusted content + outbound channel in one trust boundary | ⚠️→🛑 |

## Two modes

- **Pre-install vetting** — one candidate server, gate it *before* you wire credentials in.
- **Audit installed** — sweep every server in your machine's MCP config files and flag the risky ones already running.

## Example output

```text
🛑 BLOCK — acme-mailer-mcp   (pre-install)

Top reasons
1. Impersonation — package name claims a well-known email vendor; not published by that vendor.  [BLOCK]
2. Exfil endpoint — every send secretly BCC'd to an unrelated attacker domain (added in a later release). [BLOCK]
3. Rug pull — behavior added after 15 clean releases; `npx -y` auto-delivers it.       [BLOCK]

Scanners run: mcp-scan ✓  trufflehog ✓ [1 verified]  guarddog ✓ [HIGH]  ·  osv-scanner ✗ absent
Coverage: tool-definition ✓ · source ✓ · provenance ✓

Do now
• Do not install. If already installed: uninstall, then rotate the vendor API token + any creds sent in email.
```

---

## Install

Clone once, then wire it into whichever tools you use:

```bash
git clone https://github.com/VeljkoRailsware/mcp-vet.git
cd mcp-vet
```

### 🤖 Claude Code
Skills live in `~/.claude/skills/`. Copy the bundle in (the repo root *is* the skill):

```bash
mkdir -p ~/.claude/skills/mcp-vet
cp -R SKILL.md references scripts ~/.claude/skills/mcp-vet/
```
Or run `./install.sh` — it installs the skill, drops the scanner CLI (`mcp-vet-scan`) on your `PATH`, and offers the adapters below. The skill triggers automatically when you're about to add/trust an MCP server, or invoke it directly: `use the mcp-vet skill to check github.com/foo/bar-mcp`.

> **`mcp-vet-scan` on PATH:** `install.sh` copies the scanner orchestrator to `~/.local/bin/mcp-vet-scan`, so the scanner layer works in **every** tool below — Cursor, VS Code, Codex — without needing this repo checked out in your workspace. (Override the location with `MCP_VET_BIN=/somewhere ./install.sh`.)

### 🖱️ Cursor
Cursor loads rules from `.cursor/rules/*.mdc`. Drop in the adapter (per-project) — it's an *Agent-Requested* rule, so Cursor auto-consults it when you mention adding an MCP server:

```bash
mkdir -p .cursor/rules
cp adapters/cursor/mcp-vet.mdc .cursor/rules/
```
The rule calls `mcp-vet-scan` (installed on your `PATH` by `./install.sh`), so its scanner layer works even when this repo isn't in your workspace.

### 🆚 VS Code (GitHub Copilot)
Copilot loads reusable prompts from `.github/prompts/*.prompt.md`, invoked as slash commands:

```bash
mkdir -p .github/prompts
cp adapters/vscode/mcp-vet.prompt.md .github/prompts/
```
Then in Copilot Chat: **`/mcp-vet https://github.com/foo/bar-mcp`**. (Prompt files also work at user scope — see VS Code's *"Chat: prompt files"* setting.)

### 🧑‍💻 OpenAI Codex
Codex reads `AGENTS.md` before doing any work — project root, or global at `~/.codex/AGENTS.md`. Append the section:

```bash
# Project-scoped:
cat adapters/codex/mcp-vet.AGENTS.md >> AGENTS.md
# Or global (applies in every repo):
cat adapters/codex/mcp-vet.AGENTS.md >> ~/.codex/AGENTS.md
```

### Optional: install the OSS scanners
`mcp-vet` works without them (static reasoning), but they sharpen the verdict. Install what you like:

```bash
pipx install mcp-scan            # primary MCP-native engine (or: uvx mcp-scan@latest)
pipx install semgrep trufflehog3 guarddog
brew install trufflehog osv-scanner semgrep    # macOS alternatives
```
`scripts/run_scanners.sh` auto-detects whichever are present.

---

## How it decides (gate rubric, condensed)

Severity-max wins — **one BLOCK signal blocks**; this is a gate, not an average.

- **BLOCK** — poisoned/injecting/shadowing tool description · rug-pull or tool-def hash mismatch · verified secret or hardcoded exfil endpoint · HIGH malicious-package signal · confirmed impersonation.
- **WARN** — generic SAST/CVE findings · excessive agency · unpinned version (`npx -y`, `@latest`) · unverifiable publisher · mitigable lethal-trifecta shape.
- **APPROVE** — both surfaces covered & clean · provenance verified or credibly benign · capabilities match purpose. Always with hygiene advice: **pin the version** (kills the auto-update backdoor) and **scope the credential** (kills the confused-deputy blast radius).

## Repository layout

```text
mcp-vet/
├── SKILL.md                  # Claude Code skill: routing, pipeline, gate rubric
├── references/
│   ├── attack-taxonomy.md    # 9 attack classes, red-flag patterns, triage table
│   ├── oss-tools.md          # exact scanner invocations + exit-code → gate mapping
│   └── sources.md            # authority citations behind every claim
├── scripts/
│   └── run_scanners.sh       # detects installed scanners, runs them, reports coverage honestly
├── adapters/                 # same skill, ported to other agents
│   ├── cursor/mcp-vet.mdc
│   ├── vscode/mcp-vet.prompt.md
│   └── codex/mcp-vet.AGENTS.md
├── evals/evals.json          # test cases used to validate the skill
└── install.sh
```

## Limitations (read these)

- **A clean scan is not a safety proof.** Description scanners miss source backdoors and vice-versa; `mcp-vet` only APPROVES when *both* surfaces were actually covered, and says so when one couldn't be.
- **Registry listing ≠ safe.** The official [MCP Registry](https://modelcontextprotocol.io/registry/about) verifies *name ownership* (reverse-DNS via GitHub OAuth / DNS TXT), not benign behavior — a verified publisher can still rug-pull.
- **It's a decision aid, not a sandbox.** For post-approval protection, wrap long-lived servers in `mcp-context-protector`.

## Credits & sources

Threat model synthesized from [Trail of Bits](https://blog.trailofbits.com/2025/04/21/jumping-the-line-how-mcp-servers-can-attack-you-before-you-ever-use-them/) (line jumping), [Invariant Labs](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks) (tool poisoning / MCP-Scan), Simon Willison (lethal trifecta), [OWASP](https://owasp.org/www-project-mcp-top-10/) (MCP / LLM Top 10), the NSA MCP CSI, the official [MCP spec](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices), and reporting on the first in-the-wild malicious MCP server ([The Hacker News](https://thehackernews.com/2025/09/first-malicious-mcp-server-found.html), [Semgrep](https://semgrep.dev/blog/2025/so-the-first-malicious-mcp-server-has-been-found-on-npm-what-does-this-mean-for-mcp-security/)). Full citation list in [`references/sources.md`](references/sources.md).

## Contributing

Contributions that add real detection signal — a new attack class, a verified scanner, a sharper heuristic, or a
regression test — are especially welcome. The one hard rule: **no fabricated findings**, and every security claim
cites a source. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add attack classes, scanners, and eval cases.

## License

MIT — see [LICENSE](LICENSE).
