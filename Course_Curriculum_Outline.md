# Bruin for Data Engineers: Building Enterprise Data Platforms

A project-based training curriculum designed for experienced data engineers who are comfortable with SQL and Python but new to Bruin. The entire course is built around one evolving enterprise data platform project for a fictional institution ("Lakota Bank") so every lesson, lab, and troubleshooting exercise reinforces the same codebase, dependency graph, and business entities.

**Target operating model:** Bruin CLI with Git.

**Target warehouse:** Snowflake

**Target source control:** Platform-neutral Git with a concrete reference implementation for Gitea Actions.

---

# 1. Required Software and Prerequisites

## 1.1 Student Prerequisites

Students should already possess:

- 2+ years of production SQL
  - Window functions
  - CTEs
  - MERGE patterns
  - Dimensional modeling concepts

- 1+ year of production Python
  - pandas
  - API integration
  - Packaging basics

- Working knowledge of:
  - Git
  - Pull requests
  - Branching workflows

### Recommended Background Reading

Before starting:

- Kimball Data Warehouse Toolkit
- Snowflake Fundamentals
- Git Workflows for Analytics Engineering

---

## 1.2 Required Software

| Component | Purpose |
|------------|----------|
| Bruin CLI | Development and execution |
| Python 3.10+ | Python assets |
| Git | Source control |
| VS Code | Development |
| Docker Desktop | Source simulation |
| Snowflake Account | Target platform |
| Gitea | CI/CD workflows |
| DuckDB | Local experimentation |

---

# 2. Enterprise Project Overview

Throughout the course students build a complete enterprise banking analytics platform.

## Business Scenario

Lakota Bank wants a modern cloud-based analytics platform capable of:

- Customer analytics
- Product analytics
- Profitability reporting
- Regulatory auditability
- Historical reconstruction
- Replayability

---

## Source Systems

### Core Banking

Entities:

- Customers
- Accounts
- Transactions

### CRM

Entities:

- CRM Customers
- Interactions
- Campaigns

### Flat Files

Entities:

- Branch Metadata
- Product Reference Data

### External API

Entities:

- Currency Exchange Rates
- Economic Indicators

---

# 3. Target Architecture

```text
Sources
    ↓
Landing
    ↓
Historical (_HIST)
    ↓
Integration
    ↓
SCD2 Dimensions
    ↓
Reporting Marts
```

---

## Landing Layer

Purpose:

- Immutable snapshots
- Raw persistence
- Reprocessing support

Topics Covered:

- Initial Loads
- Incremental Loads
- Late Arriving Data
- Replay Processing

---

## Historical Layer

Tables:

```text
CUSTOMERS_HIST
ACCOUNTS_HIST
TRANSACTIONS_HIST
CRM_CUSTOMERS_HIST
```

Objectives:

- Complete auditability
- Historical reconstruction
- Source reconciliation

Topics:

- Full Reloads
- Incremental Reloads
- Source Count Validation
- Regulatory Traceability

---

## Integration Layer

Purpose:

Current state business entities.

Examples:

```text
CUSTOMER_CURRENT
ACCOUNT_CURRENT
PRODUCT_CURRENT
```

Topics:

- Business Keys
- Conformed Dimensions
- Source Standardization
- Golden Records

---

## SCD2 Layer

Purpose:

Historical business entity tracking.

Examples:

```text
DIM_CUSTOMER
DIM_ACCOUNT
```

Cover:

- Initial Loads
- New Members
- Attribute Changes
- Late Arriving Corrections
- Historical Rebuilds

---

## Mart Layer

Purpose:

Reporting-ready structures.

Examples:

```text
DIM_CUSTOMER
DIM_ACCOUNT
FACT_TRANSACTIONS
FACT_CUSTOMER_PROFITABILITY
```

Topics:

- Star Schema
- Fact Grain
- Dimension Dependencies
- Reporting Models

---

# 4. Complete Course Outline

| Module | Title | Duration |
|----------|---------|----------|
| 0 | Environment Setup | 1 hour |
| 1 | Bruin Fundamentals | 3 hours |
| 2 | Pipeline Design | 3 hours |
| 3 | SQL Assets | 4 hours |
| 4 | Landing Layer Ingestion | 3 hours |
| 5 | Python Assets | 3 hours |
| 6 | Dependency Management | 3 hours |
| 7 | Historical Layer Engineering | 4 hours |
| 8 | Integration Layer | 3 hours |
| 9 | SCD Type 2 Processing | 4 hours |
| 10 | Sensors & Cross-Pipeline Dependencies | 4 hours |
| 11 | Data Quality Frameworks | 4 hours |
| 12 | Replayability and Recovery | 4 hours |
| 13 | Git-Based Deployment | 3 hours |
| 14 | Operations and Production Support | 3 hours |
| 15 | Enterprise Capstone | 8-16 hours |

---

# Module 0: Environment Setup

## Learning Objectives

Students will:

- Install Bruin CLI
- Configure Snowflake
- Validate local environment
- Configure Git repository

---

## Hands-On Lab

### Exercise

Install:

- Bruin CLI
- Python
- Docker
- Snowflake connection

Validate:

```bash
bruin --version
```

Expected Result:

```text
CLI returns version information.
```

---

## Troubleshooting Exercise

Broken Scenario:

Missing Snowflake credentials.

Students diagnose:

```bash
bruin validate
```

---

## Knowledge Check

1. What file stores environments?
2. Why should `.bruin.yml` remain out of source control?

---

# Module 1: Bruin Fundamentals

## Learning Objectives

- Understand Bruin architecture
- Understand assets
- Understand pipelines
- Understand project structure

---

## Topics

### Project Structure

```text
Project
 ├── .bruin.yml
 ├── pipelines/
 ├── lib/
 └── docs/
```

### Core Concepts

- Projects
- Assets
- Pipelines
- Dependencies
- Environments

---

## Lab

Create:

```text
pipeline: scratch
asset: hello_world
```

Validate:

```bash
bruin validate
```

---

# Module 2: Pipeline Design

## Learning Objectives

Students learn:

- Pipeline structure
- Scheduling
- Environment management
- Reusability

---

## Lab

Build pipelines:

```text
ingest-core-banking
ingest-crm
ingest-flatfile
ingest-external-api
```

---

## Troubleshooting

Broken cron schedule.

Students identify invalid schedule syntax.

---

# Module 3: SQL Assets

## Learning Objectives

Students learn:

- SQL asset design
- Materialization strategies
- Incremental processing

---

## Materialization Types

```text
create+replace
truncate+insert
append
merge
delete+insert
time_interval
scd2_by_column
scd2_by_time
```

---

## Lab

Build:

```text
CUSTOMERS_HIST
ACCOUNTS_HIST
```

using SQL assets.

---

## Troubleshooting

Missing primary key on merge.

Students identify failure.

---

# Module 4: Landing Layer Ingestion

## Learning Objectives

Students learn:

- Seed assets
- Ingestr assets
- Landing architecture

---

## Lab

Build ingestion for:

### Core Banking

```text
Customers
Accounts
Transactions
```

### CRM

```text
Customers
Interactions
```

### Flat Files

```text
Products
Branches
```

### External API

```text
FX Rates
```

---

## Expected Outputs

Landing Tables:

```text
LANDING_CUSTOMERS
LANDING_ACCOUNTS
LANDING_TRANSACTIONS
```

---

# Module 5: Python Assets

## Learning Objectives

Students learn:

- Python asset lifecycle
- Shared libraries
- DataFrame materialization

---

## Lab

Build:

```text
fx_rates_fetch.py
```

which:

1. Calls API
2. Creates dataframe
3. Loads Snowflake

---

## Troubleshooting

Broken API endpoint.

Students diagnose:

- HTTP failures
- Authentication issues

---

# Module 6: Dependency Management

## Learning Objectives

Students learn:

- Asset dependencies
- Pipeline dependencies
- Dependency graphs
- Parallel execution

---

# Within-Pipeline Flow

```text
extract
    ↓
hist
    ↓
validate
    ↓
publish
```

---

## Topics

### Dependency Declarations

Students learn:

```text
depends
```

relationships.

---

### Parallelization

Students learn:

```text
A ─┐
   ├─► C
B ─┘
```

---

## Lab

Build complete dependency chain.

Validate lineage.

---

# Module 7: Historical Layer Engineering

## Learning Objectives

Students learn:

- Historical persistence
- Replayability
- Auditability
- Reconciliation

---

## Build

```text
CUSTOMERS_HIST
ACCOUNTS_HIST
TRANSACTIONS_HIST
```

---

## Topics

### Reprocessing

Recover:

```text
Missed Day
Corrupted Day
Partial Load
```

---

## Lab

Inject late arriving data.

Reprocess successfully.

---

# Module 8: Integration Layer

## Learning Objectives

Students learn:

- Current state entities
- Business key standardization
- Conformed entities

---

## Build

```text
CUSTOMER_MASTER
ACCOUNT_MASTER
```

---

## Lab

Merge CRM and Core Banking customer records.

---

# Module 9: SCD Type 2 Processing

## Learning Objectives

Students learn:

- Historical dimension design
- Versioning patterns
- Late arriving corrections

---

## Build

```text
DIM_CUSTOMER
DIM_ACCOUNT
```

---

## Scenarios

### Initial Load

```text
Customer A
```

Version 1

### Change

```text
Customer A Email Changed
```

Version 2 created.

---

## Lab

Rebuild SCD2 dimension from scratch.

---

# Module 10: Sensors and Cross-Pipeline Dependencies

## Learning Objectives

Students learn:

- Sensor assets
- Custom Python sensors
- Data-state dependencies

---

# Required Dependency Chain

```text
signature-daily
      ↓
PROCESSING_DATES
      ↓
banking-integration
      ↓
customer-mart
```

---

## Why Data-State Matters

Avoid:

```text
Scheduler Success
```

Use:

```text
Published Data Availability
```

Benefits:

- Replayability
- Resilience
- Failure Isolation

---

## Lab

Create processing date sensor.

---

# Module 11: Data Quality Frameworks

## Learning Objectives

Students learn:

### Built-In Checks

- Not Null
- Uniqueness
- Row Counts
- Freshness
- Schema Validation

---

### Custom Checks

- SQL Checks
- Python Checks

---

## Reusable Framework

Build:

```text
validation.py
```

Capabilities:

- Severity Levels
- Warning
- Error
- Critical

---

## Lab

Create reusable validation library.

---

# Module 12: Replayability and Recovery

## Learning Objectives

Students learn:

- Backfills
- Historical reconstruction
- Incident recovery

---

# Scenario 1

Rebuild Current State

```text
Current Table Lost
```

Recover from HIST.

---

# Scenario 2

Rebuild SCD2

```text
Dimension dropped
```

Recover from history.

---

# Scenario 3

Replay Missing Date

```text
2026-09-15 missing
```

Replay safely.

---

# Scenario 4

Corrupted Mart

Recover from lineage.

---

# Scenario 5

Accidental Delete

Restore from history.

---

# Module 13: Git-Based Deployment

## Learning Objectives

Students learn:

- Branching
- Pull Requests
- Promotion
- Production Deployment

---

# Git Flow

```text
feature/*
    ↓
pull request
    ↓
main
    ↓
staging
    ↓
production
```

---

## Gitea Actions

Build CI using:

```text
validate
deploy staging
deploy production
```

---

# Module 14: Operations and Production Support

## Learning Objectives

Students learn:

- Monitoring
- Troubleshooting
- Incidents
- Root Cause Analysis

---

## Production Activities

### Monitoring

- Pipeline Health
- Freshness
- SLA Compliance

### Incident Response

- Triage
- Diagnose
- Fix
- Deploy
- Backfill

---

## Lab

Complete incident simulation.

---

# Capstone Project

## Objective

Extend Lakota Bank platform by onboarding a Mortgage Servicing system.

---

## Capstone Requirements

Students must build:

### Sources

- Core Banking
- CRM
- Flat Files
- External API
- Mortgage Platform

---

### Pipelines

Multiple pipelines required.

---

### Data Quality

Must include:

- Reusable framework
- Blocking checks
- Warning checks

---

### Sensors

Implement:

```text
Data-state dependency model
```

---

### SCD2

Implement:

```text
DIM_CUSTOMER
DIM_ACCOUNT
DIM_MORTGAGE
```

---

### Reporting

Build:

```text
FACT_CUSTOMER_PROFITABILITY

FACT_MORTGAGE_PROFITABILITY
```

---

## Acceptance Criteria

Students must demonstrate:

- Multiple pipelines
- Cross-pipeline sensors
- Data quality framework
- Backfills
- Historical rebuilds
- Git deployment
- Production operations

---

# Assessment Strategy

## Continuous Assessment

Every module includes:

- Knowledge Check
- Hands-on Lab
- Validation Activity
- Troubleshooting Exercise

---

## Mid-Course Practical

Students repair:

```text
Broken Enterprise Platform
```

---

## Operations Drill

Students:

- Diagnose incident
- Repair platform
- Perform replay

---

## Final Capstone

Weighted Grading:

| Area | Weight |
|--------|----------|
| Architecture | 10% |
| Assets | 15% |
| Dependencies | 15% |
| SCD2 | 15% |
| Data Quality | 15% |
| Replayability | 15% |
| Git Workflow | 10% |
| Documentation | 5% |

---

# Fast-Track Options

## Fast-Track A: Engineer Productivity

Target Audience:

Experienced developers needing rapid Bruin adoption.

Focus:

- SQL Assets
- Python Assets
- Dependencies
- Sensors
- SCD2
- Backfills

Duration:

~30 Hours

---

## Fast-Track B: Architect / Lead

Target Audience:

Platform Architects

Focus:

- Dependency Design
- Data-State Contracts
- Governance
- Recovery
- Deployment
- Production Operations

Duration:

~37 Hours

---

# Recommended References

## Bruin

- Official Bruin Documentation
- Bruin CLI Documentation
- Bruin Asset Documentation
- Bruin Sensor Documentation

## Snowflake

- Snowflake Fundamentals
- Snowflake Performance Optimization

## Git

- Pro Git
- Git Branching Strategies

## Data Engineering

- Kimball Data Warehouse Toolkit
- Data Vault 2.0

## Supplemental

- DataTalksClub Data Engineering Zoomcamp
- Bruin Platform Modules
- Enterprise Bruin Skills Repository

---

# Final Learning Outcomes

By completing this curriculum students will be able to:

1. Design Bruin project structures
2. Build multi-pipeline solutions
3. Implement asset dependencies
4. Implement cross-pipeline dependencies
5. Build SQL assets
6. Build Python assets
7. Build sensor assets
8. Build custom Python sensors
9. Build enterprise data quality controls
10. Build reusable quality frameworks
11. Debug failures
12. Execute backfills
13. Reconstruct history
14. Implement SCD2 processing
15. Analyze lineage
16. Deploy through Git workflows
17. Operate production-scale Bruin platforms

The resulting platform is a realistic enterprise implementation demonstrating modern Data Engineering practices using Bruin, Snowflake, Python, Git, lineage-driven orchestration, replayability, and production operational excellence.
