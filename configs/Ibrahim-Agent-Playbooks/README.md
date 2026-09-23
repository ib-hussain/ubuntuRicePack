# Ibrahim Hussain — Extended Agent Playbooks

This is the expanded, evidence-led second edition of Ibrahim Hussain's repository instructions, technical workflows, and project memory. It is deliberately detailed. The files are meant to let a capable coding agent resume Ibrahim's work without compressing away the decisions, constraints, failure history, or verification standards established over many conversations.

## Identity boundary

These files describe **Ibrahim Hussain**, a BS Data Science student and the owner of the Fin-Glassbox, DeepDocForgery, Ubuntu/Linux customisation, SQL automation, Continue/Ollama, Windows PowerShell, and related repository work represented here.

They must not absorb history or preferences belonging to:

- Ali Asad;
- the physics teacher;
- German-language or Vienna-related conversations;
- IoT, microcontroller, or electronics work;
- Montessori, school, laboratory, travel, or unrelated account activity;
- another collaborator merely because their name appears in Git history, a team list, or a machine configuration.

When identity is uncertain, do not infer ownership from topic similarity. Ask or inspect explicit repository/user evidence.

## How to use this bundle

1. Start with `PROFILE-SELECTION.md`.
2. Copy `templates/core/AGENTS.md` to a repository root as the baseline.
3. Add the most relevant specialised template rules rather than merging every file blindly.
4. For one of the represented projects, prefer its project-specific `AGENTS.md` over a generic template.
5. Use singular `SKILL.md` files as repeatable operational workflows.
6. Use project `MEMORY.md` files as durable context plus dated historical evidence.
7. Treat the current repository, manifests, tests, and direct user corrections as more authoritative than historical memory.

## Contents

### Reusable templates

| Path | Purpose |
| --- | --- |
| `templates/core/` | General collaboration, repository safety, implementation, verification, release, and communication rules. |
| `templates/ml-systems/` | ML/DL research, data contracts, leakage prevention, HPO, checkpoints, training, evaluation, inference, and reproducibility. |
| `templates/linux-desktop-automation/` | Ubuntu, Arch, WSL, Bash, GNOME, extensions, desktop installers, compatibility, rollback, and packaging. |
| `templates/windows-data-automation/` | PowerShell, native Windows Python/PostgreSQL, Streamlit/Flask, SQL, background workers, file replacement, and desktop integrations. |
| `templates/local-ai-continue/` | Continue.dev, Ollama, local/cloud model roles, configuration, secrets, benchmarking, RAG/context, and coding-agent behaviour. |

### Project-specific packs

| Path | Purpose |
| --- | --- |
| `projects/DeepDocForgery/` | Document-forgery architecture, data/split rules, orientation safety, resumability, doctor/HPO/training workflows, evidence standards, and historical status. |
| `projects/fin-glassbox/` | Comprehensive Fin-Glassbox `AGENTS.md`, plural `SKILLS.md`, and `MEMORY.md`. |
| `projects/ubuntuRicePack/` | Ubuntu/Arch rice migration, staged installation, GNOME 48/50 compatibility, dock behaviour, autoinstall boundaries, and release overlays. |
| `projects/sqlAutomation/` | Multi-page document-to-SQL automation, approval gates, background processing, Teradata/Outlook boundaries, reports, timestamps, and recovery. |

## Instruction precedence

Use this order when instructions conflict:

1. The user's current explicit instruction.
2. The current repository's nearest `AGENTS.md`.
3. Current source code, configuration, schemas, tests, manifests, and generated verification reports.
4. The applicable project pack in this bundle.
5. The specialised template.
6. The core template.
7. Dated historical status notes.
8. Old archives, superseded prompts, and unverified chat summaries.

Do not silently reconcile contradictions. State which evidence won and why.

## Important interpretation rule

These playbooks contain three kinds of information:

- **Durable decisions:** remain binding until Ibrahim changes them, such as Fin-Glassbox's removed Fundamental branch or UbuntuRicePack's no-Snap policy.
- **Workflow preferences:** generally reusable, such as one-line commands, resumability, evidence-led debugging, replacement-only ZIPs, and explicit verification.
- **Historical snapshots:** exact counts, versions, metrics, paths, and pass totals tied to a dated run. They are useful evidence but must be rechecked before being used as current acceptance criteria.

## Editing and maintenance

- Add a date and artifact/commit identity when recording a new result.
- Preserve superseded historical snapshots for provenance, but label them as superseded.
- Do not copy secrets, private keys, tokens, passwords, or `.env` contents into these files.
- Do not turn a machine-specific path into a universal default without a configurable alternative.
- Keep README files stable and informational; use `MEMORY.md`, run reports, or progress files for changing status.
