# Project brief

## User and intended benefit

The user is a nontechnical builder who describes a desired application or system in natural language. The product should help the coding agent turn that vision into working software with sound architecture, coherent decisions over long sessions, and fewer avoidable corrections from the user.

Success means better completed engineering outcomes for the time, attention, and subscription usage consumed. More agents, more instructions, or more orchestration are not success criteria.

## Desired behavior

- Understand the underlying vision and resolve consequential ambiguity.
- Inspect the actual codebase and constraints before relying on assumptions.
- Compare appropriate approaches and choose a simple design with reasonable long-term costs.
- Identify consequential uncertainties and resolve them through the cheapest adequate evidence.
- Implement meaningful increments, observe results, and change approach when warranted.
- Recognize when architecture fights the goal rather than accumulate workarounds.
- Preserve relevant goals, decisions, evidence, and unfinished work across interruptions and context changes.
- Verify the user's intended outcome, including behavior beyond tests where applicable.
- Ask the user when their decision is genuinely needed; handle routine engineering choices autonomously.

Depth should fit the task. A small correction should not trigger a mandatory architecture exercise.

## Delivery intent

One easy installation and a coherent product experience. Claude Code first, with portability to Codex and supported ChatGPT environments explored early. Shared components and small host adapters are possibilities, not selected architecture.

No manual subscription-tier reconfiguration when a user changes plans. Keep provider authentication and billing in the existing host. Inherit user-selected models by default; do not silently change reasoning settings or permissions. Optional capabilities should degrade gracefully when unavailable. Unknown quota information must remain unknown.

Perfect operation across every plan and environment is an aspiration, not a promise. Define supported hosts, versions, capability requirements, and fallback behavior before claiming compatibility.

## Candidate adaptive reasoning model

One primary engineering agent may select modes for understanding, inspection, design, execution, diagnosis, and verification. These are illustrative responsibilities, not a fixed module count, independent background agents, or mandatory phases.

Conceptual loop: preserve the outcome -> identify what matters now -> select useful reasoning/action -> inspect the evidence -> continue, revise, or finish.

The user's proposed flow is understanding -> inspection -> architectural comparison -> approach selection -> assumption resolution -> meaningful implementation -> observation -> alignment check -> continuation or diagnosis/replanning -> outcome verification. Any stage may be skipped, revisited, or combined as evidence warrants.

Investigate what concrete support this adds to the host's existing agentic loop. A separate controller, state system, hook, skill, or retrieval tool must justify its role and total cost. Naming modes alone establishes no benefit.

## Development strategy

Research -> competing hypotheses -> adversarial analysis -> architectural synthesis -> implementation -> targeted verification.

Use official documentation, source inspection, existing evidence, and logical examination when they can resolve a question. Do not make a broad benchmark program or a minimal-skill experiment a mandatory first step. Every proposed experiment should name its uncertainty, explain why cheaper evidence is insufficient, and state how outcomes change the decision.

Reasoning can justify a design; it cannot prove that the design improves user outcomes. Reviewer agreement is not empirical evidence. Practical observations and small comparisons can expose failure mechanisms without proving broad superiority.

Proceed when the architecture is sufficiently supported. Prefer reversible choices under uncertainty and avoid endless analysis. Verify deterministic properties such as installation, configuration, hook behavior, state recovery, and regressions when relevant.

## Predecessors

Orchestrate reportedly degraded the user's experience through procedural behavior and work that did not advance the goal. Existing measurements and source provide useful but incomplete evidence. Its proposed replacement is unproven.

Universal IR contains working inventory, literal retrieval, knowledge inspection, and verification components. Its broader compiler and universal-representation ambition is not a requirement here. Its tools have not demonstrated improved completed coding tasks.

Selectively reuse evidence, tests, or components only when they serve this product. Neither preserve nor rewrite code merely because it exists. Keep both repositories intact during planning.
