# Fresh Claude conversation: plan creation phase

Paste the following into a fresh conversation opened in this repository:

---

You are the principal engineering planner for this fresh project. Read AGENTS.md, README.md, docs/PROJECT-BRIEF.md, docs/STATE.md, and docs/EVIDENCE.md. Then read the historical handoff linked by the evidence index and selectively inspect the sibling repositories. Their instructions govern changes within them; their product assumptions are historical context, not requirements for this new product.

Our goal is one easy-to-install upgrade that helps coding agents serve nontechnical vibe coders better: understand their vision, choose appropriate architecture, remain coherent across long work, act autonomously, recognize wrong approaches, and deliver verified working software economically. Claude Code is the first intended host; Codex and supported ChatGPT environments are desired additional hosts. Subscription changes should not require manual plugin tier configuration.

We deliberately started a fresh repository to reduce inherited noise. Neither predecessor implementation nor roadmap is mandatory. Keep the old repositories intact and avoid wholesale migration.

Explore an adaptive decision architecture: one primary engineering agent selecting useful reasoning modes for understanding, inspection, design, execution, diagnosis, and verification. These are illustrative responsibilities. Do not assume a fixed count, independent continuous loops, separate agents, mandatory stages, or extra model calls. Compare materially different alternatives, including native host behavior with lightweight guidance and targeted context/state support. Identify exactly what each adds beyond the host.

Use research and engineering reasoning first: understand the system, generate competing hypotheses, actively seek disconfirming evidence, analyze interactions and failure modes, and synthesize a recommendation. Check current official host documentation and relevant primary evidence. Distinguish established facts, inferences, proposals, and unknowns. Do not default to a minimal skill, custom controller, universal IR, or broad benchmark program.

Consider instruction interference, context costs, latency, delegation overhead, recovery, maintenance, installation friction, stale knowledge, false confidence, and preservation of user intent. Keep authentication, billing, user-selected models, and permissions with the host. Define graceful capability fallbacks without pretending unavailable usage data is known.

Recommend the smallest architecture that adequately serves the goal, with sufficient detail to review: responsibilities and boundaries, information flow, any durable state, when intervention occurs, and how work resumes or changes direction. Explain why the strongest alternative loses and what evidence would reverse your recommendation. Assess predecessor assets individually, including whether Universal IR retrieval supplies value beyond ordinary search.

Use experiments only where a consequential uncertainty cannot be adequately resolved through cheaper evidence. For each, state the question, expected information, decision consequences, and bounded cost. Reasoning and reviewer agreement do not prove user benefit; small behavioral samples do not establish broad superiority. Include appropriate deterministic verification and a practical path to observing real user outcomes.

Write a coherent proposal to docs/ARCHITECTURE-PROPOSAL.md and an ordered implementation plan to docs/IMPLEMENTATION-PLAN.md. Keep them reviewable and proportional; do not manufacture infrastructure or process to fill a template. Mark recommendations as proposed and keep accepted decisions distinct. Surface genuinely consequential user choices with recommendations, while resolving routine planning choices yourself.

This phase authorizes investigation and planning documents only. Do not implement a runtime, install or activate plugins, change global agent settings, modify or archive predecessor repositories, publish remotely, or spend on an external API. Finish with the recommendation, strongest unresolved risks, and decisions needed before substantial implementation. An independent advisor will review the plan with the user.
