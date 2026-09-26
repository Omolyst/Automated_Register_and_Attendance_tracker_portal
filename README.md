# Automated_Register_and_Attendance_tracker_portal

# 📊 End-to-End User Registration & Attendance Tracking System

An automated, data-driven ecosystem featuring a centralized relational database, automated cloud workflows, live data visualizations, and an embedded user portal. 

---

## 🚀 System Architecture Overview

This project integrates modern cloud platforms to handle data ingestion, relational mapping, automated transformation, and reporting inside a unified Graphical User Interface (GUI).



---

## 🛠️ Tech Stack & Role of Components

* **Google Sites:** Serves as the central, user-facing GUI hosting embedded entry points and dynamic asset dashboards.
* **Tally Forms:** Handles frictionless front-end user registration and attendance check-in data collection.
* **Make.com:** Coordinates the middle-tier pipeline, parsing webhook payloads from Tally and transforming them into structured payloads.
* **Supabase (PostgreSQL):** The analytical data layer maintaining high-integrity storage, data models, and real-time processing engines.
* **Looker Studio:** Delivers interactive visual business intelligence dashboards mapped to specific operational metrics.

---

## 💾 Database Architecture (Supabase / Postgres)

The core database design utilizes standard relational principles separating operational transactional events from static entities.

### 📐 Schema Highlights
* **Fact Tables:** Tracking event-driven metrics (e.g., `attendance_log` tracking historical individual timestamps).
* **Dimension Tables:** Maintaining entity states (e.g., `user_profiles` containing unique identifiers, registration dates, and birthdays).

### ⚡ Database Objects Included in this Repo
* **Views (`/supabase/views`):** Optimized query layouts including an aggregated Attendance View and a dynamic Birthday View calculating rolling milestone dates.
* **Functions & Triggers (`/supabase/functions`):** PL/pgSQL scripts validating system input constraints and automating state mutations instantly upon row insertion.
* **Row-Level Security (RLS):** Policies locking down internal access layers to protect PII (Personally Identifiable Information).

---

## ⚙️ Automation Workflows (Make.com)

The visual automated pipelines abstract complex API code while protecting access layers:
* **Trigger:** Instant Webhook fires upon a user clicking submit on the Tally application form.
* **Action Routing:** Conditional routers evaluate data payloads to separate fresh profile signups from standard chronological attendance entries.
* **Security Note:** All blueprints tracked in this repository utilize connection abstractions. No live API credentials or tokens are exposed.

---

## 📊 Business Intelligence & Reporting (Looker Studio)

Live reporting panels are linked directly onto read-optimized PostgreSQL views inside Supabase:
* **Attendance Analysis Dashboard:** High-level metrics showing organizational metrics, trends over time, and engagement tracking.
* **Birthday & Milestones Monitor:** A clean tracking component driving timely notifications or administration team alerts.

---

## 📂 Project Directory Structure

```text
├── .github/                 # Automated validation or deployments
├── supabase/                # Database core configurations
│   ├── migrations/          # Chronological database schema files
│   ├── views/               # SQL scripts for Looker views
│   └── functions/           # PL/pgSQL database trigger functions
├── automation/              # No-code architecture backups
│   └── make-blueprint.json  # Sanitized Make.com blueprint export
└── README.md                # System documentation
```

---

## 🔧 Installation & Local Setup

### Prerequisites
* A [Supabase Account](https://supabase.com) and the [Supabase CLI](https://supabase.com) installed locally.

### Deploying the Database
1. Clone this repository to your machine.
2. Link your local project environment to your live Supabase cloud provider dashboard:
   ```bash
   supabase link --project-ref your-supabase-project-id
   ```
3. Push the schema migrations up to apply all tables, structural views, and database functions:
   ```bash
   supabase db push```
