# Amazon CORE — Architecture Rewrite Documentation

Public-facing documentation for the **Amazon CORE Sprinklr ETL v2** rewrite at M+C Saatchi Fluency. This repo contains the architecture explorer, project roadmap, and operations panel — the working pipeline code itself lives in [`Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2`](https://github.com/Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2).

The site is published via GitHub Pages.

---

## Live Dashboards

| Dashboard | URL | Purpose |
|---|---|---|
| **Quality Dashboard** | [amazon-core-quality-dashboard.s3-website.eu-west-2.amazonaws.com](http://amazon-core-quality-dashboard.s3-website.eu-west-2.amazonaws.com/) | Live pipeline QA — run history, schema validation, filtered posts, dedup candidates, data quality issues. S3-hosted. |
| **Architecture Explorer** | [asad-ikram-mc.github.io/core_architecture_rewrite](https://asad-ikram-mc.github.io/core_architecture_rewrite/) | Interactive 5-tab architecture docs — Lambda chain, Fargate tasks, ERD, full diagram, analyst summary. |

---

## What's in here

Three standalone HTML pages — open any of them in a browser, no build step required.

| File | Purpose |
|---|---|
| [`index.html`](./index.html) | **Architecture Explorer.** Five interactive tabs covering the existing 12-Lambda pipeline, the new 10-Fargate-task architecture, the database ERD across 5 schemas, the full architecture diagram, and an analyst-facing summary. |
| [`roadmap.html`](./roadmap.html) | **Project Roadmap.** Six-phase project plan with checklists for each phase. Phases 1–5 complete, Phase 6 (Production Cutover) currently active. |
| [`ops.html`](./ops.html) | **Operations Panel.** Live operations reference — runbook, deployment commands, common SQL queries, and incident response playbook. |

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
- **MBS automation via T8** — no more manual SQL scripts after Monday pushes.
- **Auto-detect dedup via T9** ★ — operator approves on Mondays. Pipeline never auto-deletes.
- **Schema parity** — `adl.posts_current` matches old `sprinklr_table` exactly. Tableau cutover = connection-string change only.

---

## Current status (2026-06-10)

### Pipeline: First full E2E run SUCCEEDED ✅

The v2 pipeline ran end-to-end (T0→T9) for the first time on 2026-06-10. All 9 steps
succeeded in ~17 minutes. Key findings from the first run:

| Check | Status | Notes |
|---|---|---|
| T0 Schema Validation | ✅ | All 23 source files pass. Schema contract seeded for Organic_Tags_1 (63 cols — Sprinklr renamed CCR→GCCI columns in 2026-06) |
| T1 Ingest | ✅ | POST_ID_VALUE fix applied — tag_pull_raw now stores numeric Sprinklr post_ids (was storing permalink URLs, breaking T5 join) |
| T2 Transform | ✅ | 4,971 rows written to ODL across 8 platforms |
| T3 Collab+LINE | ✅ | 7 per-country tracker sheets (updated from old combined sheet) + correct LINE JP workbook |
| T4 Filter | ✅ | |
| T5 Tags | ✅ (partial) | SCD2 close/re-insert conflict on same-day valid_from — under investigation. Tag join confirmed working (numeric post_ids match). |
| T6 Benchmark | ✅ | |
| T7 Push+QA | ✅ | |
| T8 Corrections | ✅ | |
| T9 Dedup | ✅ | |

### Next: controlled comparison run

DB wiped clean (ref tables + permalink_registry preserved). Plan:
1. Re-run the pipeline for the same pull dates as the last few runs in `sprinklr_table` (old DB, last run 2026-06-07)
2. Compare v2 output vs old DB row counts, reptopic distribution, platform breakdown
3. If match → backfill all historical data
4. If match + stable for 2 weeks → cut Tableau over to v2 DB

---

## Recent milestones

| Date | Milestone |
|---|---|
| **2026-06-10** | **First full E2E run SUCCEEDED** — T0→T9 in 17 minutes. POST_ID_VALUE fix. Schema contract seeded for all 23 files. |
| **2026-06-10** | **DB rebuild completed** — full schema wipe + migration replay (migrations 001–037), all ref tables reseeded from S3, column_mappings updated to 62-col old pipeline spec, permalink_registry preserved (40,164→41,095 rows). |
| **2026-06-10** | **Sprinklr schema change handled** — Organic_Tags_1 grew from 59 to 63 columns (CCR→GCCI renames + 4 new fields). T0 schema contract and column_mappings updated to match. |
| **2026-06-10** | **L8/L9/L11 parity** — sheets_loader updated to 7 per-country collab trackers + correct LINE JP workbook. T11 follower task built (LinkedIn follower overrides via ref table, not hardcode). |
| **2026-06-10** | **Amazon Sprinklr access confirmed** — exec_social, publisher_partnership, linkedin_global fields now fully populated in old pipeline (7,888/7,888 rows). |
| **May–Jun 2026** | Legacy parity sprint — paid/organic decoupling, NULL-vs-0 policy, country leakage, multi-region LI, LINE aggregation, paid-data ingestion. |
| **Apr 2026** | T9 Dedup, T8 Corrections deployed. Full pipeline E2E running daily. |
| **Mar 2026** | T0–T7 containerised. Step Functions state machine deployed. |
| **Feb 2026** | Phase 1 Foundation — ECS cluster, RDS (5 schemas), ECR, IAM, SNS. |

---

## Repos

| Repo | Contents |
|---|---|
| [`asad-ikram-mc/core_architecture_rewrite`](https://github.com/asad-ikram-mc/core_architecture_rewrite) (this repo) | Public-facing architecture, roadmap, and operations docs |
| [`Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2`](https://github.com/Fluency-M-C-Saatchi/amazon_sprinklr_etl_v2) | The working pipeline — Fargate task code, SQL migrations, infrastructure, Step Functions |
| [`Fluency-M-C-Saatchi/amazon_sprinklr_etl`](https://github.com/Fluency-M-C-Saatchi/amazon_sprinklr_etl) | The legacy 12-Lambda pipeline being replaced |

---

## Contact

**Asad Ikram** — Data Engineer, M+C Saatchi Fluency
