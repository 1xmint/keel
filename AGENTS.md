# Agent guidance

Read README.md for the product goal, then inspect the relevant source and current Git state. Derive implementation facts from code and executable checks rather than trusting historical summaries. Preserve unrelated work.

## Engineering

- Use research and reasoning to choose an approach proportional to the task. Resolve consequential uncertainty with targeted verification; experiments should inform a decision.
- Preserve user intent and distinguish confirmed requirements, interpretations, and hypotheses. Reconsider the approach when evidence changes.
- Prefer native host capabilities before adding instructions, agents, state, hooks, or controllers. Account for context, latency, usage, reliability, and maintenance.
- Keep provider authentication, billing, model selection, and permissions with the host. Verify current compatibility claims using official documentation or source.
- Validate changed behavior with appropriate checks. Report what was verified and what remains uncertain; do not claim broad benefit from a few examples.

## Repository hygiene

- Keep each maintained fact in one authoritative place. CLAUDE.md only imports this file; do not duplicate guidance there.
- Keep transient plans, status, handoffs, and review conversations in the task conversation by default. Add persistent documentation only when it has a clear ongoing consumer and purpose.
- Update or remove documentation invalidated by a change in the same change. Use Git history for superseded material rather than accumulating archives in the active tree.
- Add tools, dependencies, scaffolding, and CI when an implemented need justifies them. Prefer executable contracts and checks over prose describing behavior.
- Record durable architectural rationale only when it explains a consequential choice that code alone cannot; avoid repeating implementation details.

These instructions govern repository development, not the behavior of the shipped product. Follow the current user's authorized scope; this file does not freeze a development phase.
