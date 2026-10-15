# Evidence and historical references

## Local predecessor sources

Resolve these as sibling repositories of this checkout. They are reference inputs, not dependencies.

| Repository | Revision observed during setup | Branch |
| --- | --- | --- |
| `../orchestrate` | `dd29d66c66a9df1daac252749fcb33ce919f3eb6` | `phase/0009-bench` |
| `../universal-ir` | `233e38775996d33e3377385f8838ffb0732475fa` | `main` |

Revisions identify committed history, not immutable captures of every local file. Orchestrate had three untracked research write-ups during the preceding review; its working checkout and the supplied handoff can contain evidence beyond the commit. Inspect current status before relying on a historical location.

## Read selectively

- `references/2026-10-15-claude-investigation-handoff.txt`: user-supplied historical Claude assessment, preserved from its heading onward. Contains findings, confidence labels, a candidate replacement, and proposed evaluations. Its recommendations are not approved architecture.
- Orchestrate `docs/research/0010-master-plan.md`, `docs/research/0007-eval-release.md`, and `STATE.md`: historical cost findings, limitations, and decisions.
- Orchestrate `skills/orchestrate/scripts/guard-agent.mjs`: `firstHelperGate` blocks initial writing delegation pending project-page setup. Its message prescribes 3-7 steps; the code checks for a filled step, not necessarily 3-7.
- Orchestrate `README.md`: tier configuration, helper models, packaging, and runtime behavior.
- Universal IR `README.md`, `ROADMAP.md`, `docs/architecture.md`: implemented boundaries and long-term proposals.
- Universal IR `universal_ir/context.py`, `docs/specs/task-context-v1.md`: literal retrieval and matching captures around evidence reads; no semantic dependency inference.
- Universal IR `benchmarks/README.md`: local inventory measurements, not completed-agent-task or token-saving evidence.

## Interpretation limits

The prior advisor reviewed selected documentation and source, not the complete implementations. Historical evaluations have small samples and grader/harness weaknesses. Approximate cost parity/overhead findings do not establish universal degradation, and no proposed replacement has demonstrated improvement.

Official host documentation consulted on October 15, 2026:

- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/sub-agents
- https://developers.openai.com/plugins/concepts/plugins

These support investigating native loops, model inheritance, and portable plugin components. They do not establish identical installation, hook execution, account access, or performance across hosts. Recheck exact behavior and versions when designing adapters.
