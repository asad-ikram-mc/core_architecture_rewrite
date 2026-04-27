# Amazon CORE — Architecture Rewrite Documentation

Public-facing documentation for the **Amazon CORE Sprinklr ETL v2** rewrite at M+C Saatchi Fluency. This repo contains the architecture explorer, project roadmap, and operations panel — the working pipeline code itself lives in [`Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2`](https://github.com/Fluency-M-C-Saatchi/Fluency-M-C-Saatchi).

The site is published via GitHub Pages.

---

## What's in here

Three standalone HTML pages — open any of them in a browser, no build step required.

| File | Purpose |
|---|---|
| [`index.html`](./index.html) | **Architecture Explorer.** Five interactive tabs covering the existing 12-Lambda pipeline, the new 10-Fargate-task architecture, the database ERD across 5 schemas, the full architecture diagram, and an analyst-facing summary. Click any node for the simple story + technical detail. |
| [`roadmap.html`](./roadmap.html) | **Project Roadmap.** Six-phase project plan with checklists for each phase. Click items to mark them done — state persists in localStorage. Phases 1–5 complete, Phase 6 (Production Cutover) currently active. |
| [`ops.html`](./ops.html) | **Operations Panel.** Live operations reference — runbook, deployment commands, common SQL queries, and incident response playbook for the production pipeline. |

---

## Architecture at a glance

```
EventBridge (daily 7AM UTC)
        │
        ▼
Step Functions Standard Workflow
        │
   ┌────┴────────────────────────────────────────────────────────────┐
   ▼                                                                 ▼
T0 Validate  →  T1 Ingest [+URL canonical]  →  T2 Merge  →  T3 Collab+LINE
                                                              (Mondays only)
                                ↓
T4 Filter (22 rules)  →  T5 Tags  →  T6 Benchmark  →  T7 Push+QA
                                                              ↓
                          T8 Corrections  →  T9 Dedup ★ NEW  →  Pipeline-Success
                                                                       │
                                                                       ▼
                                                                   Tableau
                                                              (adl.posts_current,
                                                               162 columns, daily)
```

**Key changes from the old Lambda pipeline:**

- **12 Lambdas → 10 Fargate tasks** orchestrated by Step Functions instead of S3 `done.txt` event chains.
- **Daily Tableau** instead of Monday-only — analysts see Tuesday's posts on Wednesday.
- **No more 240s sleep** in copy/ingest — replaced by proper task completion signals (saves ~48 hrs/yr of billed idle).
- **No more race condition** between Lambdas 5/8/9 — Step Functions enforces sequential ordering.
- **JSONB raw archive** in `rdl.sprinklr_raw_posts` — full pipeline replay possible without re-pulling from Sprinklr.
- **One queryable QA layer** (`qa.pipeline_runs`, `qa.filtered_posts`, `qa.duplicate_candidates`) replacing scattered CloudWatch logs and 5 separate filtered_posts CSVs.
- **MBS automation via T8** (`ref.mbs_updates`, `ref.custom_metric_corrections`, `ref.x_quote_deletions`) — no more manual SQL scripts after Monday pushes.
- **Auto-detect dedup via T9** ★ — 6 detection queries flag duplicates into `qa.duplicate_candidates`. Operator approves on Mondays via `SELECT qa.approve_dedup()`. **Pipeline never auto-deletes.**
- **URL canonicalisation in T1** — Facebook `/photo.php?fbid=X` and Instagram `/reel/X` collapsed to canonical forms before INSERT, killing Q4/Q5 duplicates at source.
- **Schema parity** — `adl.posts_current` has 162 columns matching old `sprinklr_table` exactly. Tableau cutover requires only a connection-string change.

---

## Recent milestones

| Date | Milestone |
|---|---|
| **Apr 2026** | T9 Duplicate Detection deployed ★ — 6 detection queries, `qa.duplicate_candidates` table, SQL approval helpers (`qa.approve_dedup`, `qa.preview_dedup`, `qa.reject_dedup`), Slack Monday review alert |
| **Apr 2026** | URL canonicalisation in T1 — FB `/photo.php?fbid=X` and IG `/reel/X` rewritten at ingest |
| **Apr 2026** | T8 Post-pipeline Corrections deployed — replaces Lambda 10, automates MBS bulk updates, custom metric corrections, X quote deletions |
| **Apr 2026** | Schema parity achieved — `adl.posts_current` expanded 96 → 122 columns matching Lambda 7 exactly; Fix A (Lambda 5 'Global' defaults) + Fix B (filter reason strings) applied |
| **Apr 2026** | `post_id_key` made stable — uses Permalink for organic/boosted (Sprinklr `post_id` is unstable); UNIQUE constraint enforces atomicity |
| **Apr 2026** | Full pipeline E2E running daily — T0 → T9 in ~13 minutes |
| **Mar 2026** | T0–T7 containerised, Step Functions state machine deployed, all 19 REF tables seeded |
| **Feb 2026** | Phase 1 Foundation — ECS cluster, RDS schemas (5), ECR, IAM, SNS, GitHub Actions CI/CD |

See [`roadmap.html`](./roadmap.html) for the full phase-by-phase breakdown.

---

## Viewing the docs locally

No build step. Either:

```bash
# Open directly in browser
open index.html       # macOS
xdg-open index.html   # Linux
start index.html      # Windows
```

Or serve via Python's built-in HTTP server if you need a real URL:

```bash
python3 -m http.server 8080
# Then visit http://localhost:8080/index.html
```

---

## Repos

| Repo | Contents |
|---|---|
| [`asad-ikram-mc/core_architecture_rewrite`](https://github.com/asad-ikram-mc/core_architecture_rewrite) (this repo) | Public-facing architecture, roadmap, and operations docs |
| [`Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2`](https://github.com/Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2) | The working pipeline — Fargate task code, SQL migrations, infrastructure JSON, Step Functions state machine |
| [`Fluency-M-C-Saatchi/amazon_sprinklr_etl`](https://github.com/Fluency-M-C-Saatchi/amazon_sprinklr_etl) | The legacy 12-Lambda pipeline being replaced |

---

## Contact

**Asad Ikram** — Data Engineer, M+C Saatchi Fluency

Project lead, architecture & implementation. Questions on the rewrite welcome.
