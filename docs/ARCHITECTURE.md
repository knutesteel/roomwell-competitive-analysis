# Roomwell — Technical Architecture (V1)

**Status:** Draft v0.1 · 2026-05-19
**Companion to:** `docs/PRD.md` v0.2
**Repo note:** Migrates to the new private product repo with the PRD.

---

## 0. TL;DR

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Next.js 15 (App Router) + TypeScript strict** | Server Components for fast practitioner dashboard, SSR for SEO on booking pages, single framework for public + private surfaces |
| UI | **Tailwind CSS + shadcn/ui** | Owned components, no vendor lock-in, accessible primitives via Radix |
| API | **Server Actions (internal) + Route Handlers (public/webhooks)** | Type-safe internal mutations, explicit REST only where external callers need it |
| Background jobs | **Inngest** | Typed event-driven, observable retries, BAA-capable on growth tier — beats DIY pg_cron for CSV import + reminders + calendar sync |
| Database | **Postgres on Supabase** + **Drizzle ORM** | Drizzle's SQL-first ergonomics > Prisma's magic; Supabase gives us RLS as a defense-in-depth backstop |
| Auth | **Supabase Auth** (magic link primary, email/password fallback, optional TOTP MFA) | Already in the Supabase bundle, BAA path exists, no extra vendor |
| Hosting | **Vercel Pro (V1) → Vercel Enterprise or Render when we sign BAAs** | Best Next.js DX; upgrade path is real, not hypothetical |
| Email | **Postmark** | Best transactional deliverability, BAA-capable, clean templates |
| SMS (V1.1) | **Twilio Programmable Messaging** | BAA-capable, manages 10DLC registration |
| File storage | **Supabase Storage** | Same vendor as DB, RLS-aware, encrypted at rest |
| Secrets/KMS | **AWS KMS** for envelope encryption of PHI fields | Industry-standard, BAA-capable, decouples key custody from DB |
| Observability | **Sentry** (errors, with PHI redaction) + **Axiom** (logs) + **Vercel Web Vitals** | Pragmatic; Sentry signs BAAs |
| Repo structure | **Turborepo monorepo (`pnpm`)** with apps + packages | Modest upfront cost; high payoff for iOS reuse + CSV-import job runtime separation |

**Where I'm pushing back on your defaults:** I'm not recommending pure-Supabase-everything. Supabase Storage, Auth, and Postgres are great; Supabase Edge Functions for our background work are a step down from Inngest. I'm also recommending **Drizzle over Prisma** and a **monorepo from day one** even though it's more setup. Reasoning in §3.

---

## 1. Architecture diagram (text form)

```
                           ┌────────────────────────────────────────────────┐
                           │  roomwell.com (marketing site — already live)   │
                           └────────────────────────────────────────────────┘

  ╔═════════════ Public web surface ═══════════════╗   ╔═════ Practitioner web app ═════╗
  ║                                                ║   ║                                ║
  ║  /[handle]          public booking page        ║   ║  /dashboard                    ║
  ║  /intake/[token]    tokenized intake form      ║   ║  /clients                      ║
  ║  /counter/[token]   accept/decline counter     ║   ║  /calendar                     ║
  ║  /review/[token]    post-visit review          ║   ║  /services                     ║
  ║                                                ║   ║  /settings                     ║
  ║  → SSR / ISR, edge-rendered for Core Web Vitals║   ║  /reports                      ║
  ║  → Rate-limited via Upstash Redis              ║   ║                                ║
  ║                                                ║   ║  → RSC-first, magic-link auth  ║
  ╚════════════════════════════════════════════════╝   ╚════════════════════════════════╝
                       │                                              │
                       │                                              │
                       ▼                                              ▼
            ┌──────────────────────────────────────────────────────────────┐
            │                   Next.js 15 (Vercel)                         │
            │  • App Router                                                  │
            │  • Server Components + Server Actions                          │
            │  • Route Handlers for public + webhooks                        │
            │  • Middleware: auth, rate-limit, audit-context                 │
            └──────────────────────────────────────────────────────────────┘
                       │                  │                 │              │
        ┌──────────────┘                  │                 │              └──────────────┐
        ▼                                 ▼                 ▼                             ▼
┌────────────────┐            ┌────────────────────┐  ┌──────────────┐         ┌──────────────────┐
│  Supabase      │            │  Inngest           │  │  Postmark    │         │  AWS KMS         │
│  • Postgres    │◀───reads──▶│  • Reminders cron  │  │  • Tx email  │         │  • PHI envelope  │
│  • Auth        │            │  • CSV import jobs │  │  • Reminders │         │    encryption    │
│  • Storage     │            │  • Calendar sync   │  │  • Intake +  │         │  • Per-tenant    │
│  • RLS policies│            │  • State expiry    │  │    counter   │         │    DEKs          │
└────────────────┘            │  • Review prompts  │  │    emails    │         └──────────────────┘
        ▲                     └────────────────────┘  └──────────────┘                  ▲
        │                              │                                                 │
        │                              ▼                                                 │
        │                     ┌────────────────┐                                         │
        │                     │  Google        │                                         │
        │                     │  Calendar API  │ ─── one-way push, OAuth refresh         │
        │                     └────────────────┘                                         │
        │                                                                                │
        └─── app reads/writes PHI via lib/db/scoped + lib/crypto/phi ────────────────────┘
                  (RLS policies = backstop; app-level scoping = primary)

                ┌──────────────────────────────────────────────┐
                │  Observability                                │
                │  • Sentry (errors, PHI-redacted)              │
                │  • Axiom (logs, structured, PHI-redacted)     │
                │  • Vercel Web Vitals (no PHI)                 │
                │  • Audit log table → S3 with object-lock      │
                └──────────────────────────────────────────────┘
```

---

## 2. Stack — choices and tradeoffs

### 2.1 Frontend: Next.js 15 App Router

**Why:** One framework covers both the SEO-critical public booking page (SSR/ISR) and the JS-heavy practitioner dashboard (RSC + Server Actions). Vercel deploys it natively. Most of the engineering market knows it.

**Alternatives considered:**
- **Remix** — leaner data-loading model, but smaller ecosystem and weaker RSC story today.
- **SvelteKit** — beautiful DX, but smaller hiring pool and fewer accessible component libraries.
- **Astro for marketing + separate React SPA for dashboard** — split-brain, two deploys, two design systems. Not worth it.

**Decision:** Next.js 15 App Router.

### 2.2 UI: Tailwind + shadcn/ui (Radix primitives)

**Why:** shadcn copies components into your repo so you own them — no breaking changes from a vendor. Radix gives WCAG-compliant primitives for free. Tailwind keeps the styling consistent across practitioner UI and the customer-facing booking page (which should inherit roomwell.com's marketing-site design language once that file is shared).

**Alternatives:** MUI (too opinionated, hard to match marketing site), Chakra (declining momentum), Headless UI alone (less batteries-included).

### 2.3 API surface: Server Actions + Route Handlers (no tRPC in V1)

**Why:** For a web-only V1 with one client (the Next.js app itself), Server Actions are the cleanest path — typed end-to-end, no extra runtime, no API serialization layer. We reserve Route Handlers for surfaces that genuinely need a public HTTP API:

| Public/external surface | Why a Route Handler, not a Server Action |
|---|---|
| `POST /api/booking/[handle]/request` | Called by unauthenticated client browsers on the booking page |
| `POST /api/intake/[token]` | Tokenized public form submission |
| `POST /api/counter/[token]/{accept,decline}` | Tokenized public links |
| `POST /api/review/[token]` | Tokenized public form |
| `POST /api/webhooks/postmark/{bounce,complaint}` | Postmark inbound webhooks |
| `POST /api/webhooks/google/calendar` | Future, for sync notifications |
| `POST /api/inngest` | Inngest function dispatch |
| `GET /api/ical/[signed_token].ics` | iCal subscribe URL |

**Defer:** tRPC. It becomes worthwhile when (a) we ship the React Native iOS app or (b) we open an external API for integrations. At that point, both Server Actions and Route Handlers can be refactored behind a tRPC layer that mounts at `/api/trpc`. No rework today.

### 2.4 Background jobs: Inngest (not Supabase pg_cron)

**Why I'm pushing back on the Supabase-everything default:** Three V1 features are background-job-shaped, and they're not trivial:

1. **Reminders.** Cron every 5 min, find appointments needing a reminder, send email, update ledger, handle Postmark failures with backoff.
2. **CSV import.** Long-running, multi-step (parse → validate → batch insert → rollback on error → notify practitioner), needs progress reporting.
3. **Calendar sync.** OAuth refresh, push appointments to Google, handle quota errors, retry, mark connection broken if 3 consecutive failures.
4. **State expiry.** Booking requests transition `requested → expired` after 48h, `countered → expired` after 72h.
5. **Review prompts.** Send post-visit review email N hours after `completed`.

Doing all of these with `pg_cron` + Supabase Edge Functions means we DIY retries, dead-letter queues, idempotency, and observability. Inngest gives us those primitives with typed event handlers. Free tier covers our V1 volume; growth tier (~$50/mo) covers BAA when we need it.

**Alternatives:** Trigger.dev (similar, fine choice — Inngest has better TS ergonomics IMO), Temporal (overkill for our scale), QStash (lower-level, more wiring).

### 2.5 Database: Postgres on Supabase, Drizzle ORM

**Postgres on Supabase** — non-controversial. Gives us RLS as defense-in-depth, point-in-time recovery, pgvector if we ever want embeddings, storage and auth in the same vendor.

**Drizzle over Prisma:**
- Drizzle's query builder is SQL-shaped — easier to reason about, easier to optimize, easier to switch off Postgres later if needed.
- No code generation step, no client binary, no engine layer at runtime.
- TS inference is genuinely better — JOINs return correctly typed rows without manual type assertions.
- Prisma's migrations are nicer DX-wise, but Drizzle Kit has closed the gap.

**One Prisma caveat we lose:** the visual schema browser. Worth it for the runtime simplicity.

### 2.6 Auth: Supabase Auth

**Why:** Bundled with the database (no extra vendor), supports magic link + password + TOTP MFA, BAA available on Supabase Enterprise.

**Magic link primary** for the non-technical audience. Email/password as fallback for users who hate magic links. Optional TOTP MFA in settings — push toward enabling it for accounts that store PHI.

**Alternative considered:** Clerk — nicer UX out of the box, but adds a vendor and cost, and we already need Supabase for the DB. Skip.

**Decision:** Supabase Auth, with email templates customized via Postmark for brand consistency (Supabase's defaults are forgettable).

### 2.7 Hosting: Vercel Pro for V1, with a documented escape hatch

**Why Vercel for V1:** Best Next.js DX, edge network, preview deploys per PR, zero infra to manage. Vercel Pro is fine for V1 because we're **not signing BAAs in V1**.

**The honest tradeoff:** When we sign our first BAA (V2 target), Vercel requires Enterprise tier (~$500+/mo) for HIPAA coverage. The migration path:
- **Option A:** Pay for Vercel Enterprise — minimal code change.
- **Option B:** Move to Render or Railway — both offer BAAs on standard plans. Next.js runs fine on Render via their native Next.js support or Docker.
- **Option C:** Self-host on AWS ECS — most control, most ops burden.

**We design V1 to be portable** — no Vercel-specific APIs beyond the well-supported subset (Edge Runtime, ISR, Server Components). Inngest, Supabase, Postmark, AWS KMS are all host-agnostic.

### 2.8 Email: Postmark (transactional), no marketing email in V1

Postmark wins on deliverability for transactional and signs BAAs. Resend is the trendy choice but no BAA yet — disqualifies it for our path.

**Marketing email** (newsletters, drip campaigns) is deferred to V2. When it lands, the right tool is probably Customer.io or Loops — separate from transactional.

### 2.9 SMS (V1.1 only): Twilio

Programmable Messaging signs BAAs. We start 10DLC registration during V1 build so SMS launches with the V1.1 release.

### 2.10 PHI encryption: AWS KMS + envelope encryption

**Why not just rely on Supabase's at-rest encryption?** Supabase encrypts the disk, which protects against disk theft. It does *not* protect against:
- A misconfigured RLS policy leaking PHI via SQL.
- A breach of Supabase itself.
- An internal Supabase operator with DB access.

**Envelope encryption pattern:**
- AWS KMS holds the **master key** (KEK). Never leaves KMS.
- Each practitioner account has a **data encryption key** (DEK), generated at signup, encrypted by KEK, stored in the `accounts` table.
- PHI fields (`soap_notes.encrypted_data`, `intake_submissions.encrypted_data`, `clients.notes`) store ciphertext encrypted by the practitioner's DEK.
- Application decrypts DEK via KMS (round-trip per request, cached for the request lifetime), then decrypts/encrypts PHI client-side in the Next.js server runtime.
- DB sees only ciphertext for PHI. A SQL-only leak yields useless bytes.

This is more work than `pgcrypto`'s `pgp_sym_encrypt` but materially stronger. Implementation lives in `packages/crypto`.

---

## 3. Folder structure (new private product repo)

```
roomwell-app/                                # New private repo
├── apps/
│   └── web/                                 # Next.js 15 app
│       ├── app/
│       │   ├── (practitioner)/              # Auth-gated practitioner UI
│       │   │   ├── layout.tsx               # Shell + nav + auth guard
│       │   │   ├── dashboard/page.tsx
│       │   │   ├── clients/
│       │   │   │   ├── page.tsx             # List
│       │   │   │   ├── new/page.tsx
│       │   │   │   ├── [clientId]/page.tsx  # Detail
│       │   │   │   └── import/page.tsx      # CSV import UI
│       │   │   ├── calendar/
│       │   │   │   ├── page.tsx             # Week (default)
│       │   │   │   ├── day/page.tsx
│       │   │   │   └── month/page.tsx
│       │   │   ├── services/page.tsx
│       │   │   ├── settings/
│       │   │   │   ├── profile/page.tsx
│       │   │   │   ├── vertical/page.tsx
│       │   │   │   ├── discounts/page.tsx
│       │   │   │   ├── reminders/page.tsx
│       │   │   │   ├── calendar-sync/page.tsx
│       │   │   │   ├── referrals/page.tsx
│       │   │   │   └── billing/page.tsx
│       │   │   ├── reports/page.tsx
│       │   │   └── requests/                # Inbox for online booking requests
│       │   │       └── page.tsx
│       │   ├── (public)/                    # Unauthenticated client-facing
│       │   │   ├── [handle]/page.tsx        # Public booking page
│       │   │   ├── [handle]/book/page.tsx
│       │   │   ├── intake/[token]/page.tsx
│       │   │   ├── counter/[token]/page.tsx
│       │   │   └── review/[token]/page.tsx
│       │   ├── (auth)/
│       │   │   ├── signup/page.tsx
│       │   │   ├── login/page.tsx
│       │   │   └── magic-link/page.tsx
│       │   └── api/
│       │       ├── booking/[handle]/route.ts
│       │       ├── intake/[token]/route.ts
│       │       ├── counter/[token]/route.ts
│       │       ├── review/[token]/route.ts
│       │       ├── ical/[signedToken]/route.ts
│       │       ├── webhooks/
│       │       │   ├── postmark/route.ts
│       │       │   └── google/route.ts
│       │       └── inngest/route.ts
│       ├── components/                      # App-specific composed UI
│       ├── lib/
│       │   ├── auth/                        # Session helpers, middleware
│       │   ├── db/                          # Scoped query helpers
│       │   ├── actions/                     # Server Actions
│       │   └── csv/                         # CSV parsing helpers (client side)
│       ├── middleware.ts
│       ├── next.config.mjs
│       └── tsconfig.json
├── packages/
│   ├── db/                                  # Drizzle schema + migrations + seed
│   │   ├── schema/
│   │   │   ├── accounts.ts
│   │   │   ├── clients.ts
│   │   │   ├── appointments.ts
│   │   │   ├── intake.ts
│   │   │   ├── soap.ts
│   │   │   ├── services.ts
│   │   │   ├── discounts.ts
│   │   │   ├── reminders.ts
│   │   │   ├── referrals.ts
│   │   │   ├── reviews.ts
│   │   │   ├── calendar.ts
│   │   │   ├── csv-imports.ts
│   │   │   └── audit-log.ts
│   │   ├── migrations/
│   │   └── seed/
│   ├── core/                                # Pure domain logic, no I/O
│   │   ├── booking/
│   │   │   ├── state-machine.ts             # requested → confirmed/countered/declined/expired
│   │   │   ├── availability.ts              # Slot computation
│   │   │   └── soft-hold.ts
│   │   ├── checkout/                        # Cost → discount → tip → balance math
│   │   ├── referrals/                       # Points calculation
│   │   ├── reports/                         # Aggregations
│   │   └── reminders/                       # Reminder ladder rules
│   ├── crypto/                              # PHI encryption (KMS + envelope)
│   │   ├── kms.ts
│   │   ├── envelope.ts
│   │   ├── fields.ts                        # encryptField / decryptField helpers
│   │   └── tokens.ts                        # HMAC-signed public tokens
│   ├── jobs/                                # Inngest functions
│   │   ├── reminders/
│   │   ├── csv-import/
│   │   ├── calendar-sync/
│   │   ├── state-expiry/
│   │   └── review-prompts/
│   ├── email/                               # Postmark templates + sender
│   │   ├── templates/
│   │   │   ├── booking-confirmation.tsx
│   │   │   ├── counter-proposal.tsx
│   │   │   ├── intake-request.tsx
│   │   │   ├── reminder.tsx
│   │   │   └── review-prompt.tsx
│   │   └── send.ts
│   ├── auth/                                # Supabase wrappers + RBAC scaffolding
│   ├── ui/                                  # Shared UI primitives (future RN reuse)
│   │   └── components/
│   └── config/                              # Shared TS / ESLint / tsconfig bases
├── infra/                                   # IaC (Pulumi or Terraform, V1.x)
├── docs/                                    # Migrated PRD, ARCHITECTURE, ROADMAP, etc.
├── scripts/                                 # Dev helpers (seed, reset, key rotation)
├── .github/workflows/
│   ├── ci.yml                               # Lint, type, test, build
│   ├── deploy-preview.yml                   # Vercel preview on PR
│   └── deploy-production.yml
├── .env.example
├── package.json
├── pnpm-workspace.yaml
├── turbo.json
└── README.md
```

**Why monorepo from day one** (pushing back on the "just one Next.js project" default):
- `packages/core` keeps domain logic testable in isolation from Next.js — booking state machine, referral points math, checkout calculation.
- `packages/crypto` is the most security-sensitive code in the codebase. Isolated package = easy to find for review, easy to lock down with CODEOWNERS later.
- `packages/jobs` runs in Inngest's runtime, not Next.js's — separation forces clean boundaries.
- `packages/ui` and `packages/db` are pre-positioned for React Native reuse in V2.

The Turborepo overhead is ~half a day of setup. Worth it.

---

## 4. Data model (V1)

### 4.1 Core entities (simplified)

```
accounts                                   # The tenant (one solo practitioner per row in V1)
  id (uuid pk)
  email
  business_name, business_phone, business_address
  slug (unique)                            # roomwell.com/[slug]
  vertical                                 # massage|aesthetics|hair|barber
  time_zone
  plan                                     # free|paid
  encrypted_dek (bytea)                    # DEK, wrapped by AWS KMS KEK
  auto_confirm_bookings (bool)
  default_reminder_offsets (int[])         # e.g. [-1440] = 24h before
  created_at, soft_deleted_at

users                                      # Auth identities (1:1 with accounts in V1; designed for 1:N later)
  id, account_id (fk), email, role (enum: 'owner'), created_at

clients
  id, account_id (fk)
  name, email, phone
  encrypted_notes (bytea)                  # Practitioner free notes (PHI-grade handling)
  referrer_client_id (fk, nullable)
  points_balance (int)
  soft_deleted_at, created_at

intake_form_versions
  id, vertical, version (int), schema_json # Vertical-specific schema
  published_at, archived_at

intake_submissions
  id, account_id, client_id, intake_form_version_id
  encrypted_data (bytea)                   # PHI
  submitted_at, token_id (fk)

intake_tokens                              # Tokenized email completion links
  id, account_id, client_id, hmac_signature
  expires_at, consumed_at (nullable)

services
  id, account_id, name, duration_minutes, price_cents
  is_active, points_value (int, nullable)  # For referral redemption
  visibility_verticals (text[])            # Allowed verticals — V1 typically just one
  created_at

appointments
  id, account_id, client_id (fk), service_id (fk)
  starts_at, ends_at
  status                                   # requested|confirmed|countered|declined|expired|completed|cancelled|no_show
  source                                   # internal|public_booking|import
  counter_proposed_starts_at (nullable)
  counter_proposed_ends_at (nullable)
  soft_hold_expires_at (nullable)
  status_expires_at (nullable)             # For requested + countered auto-expiry
  notes_brief (text, NOT PHI)              # E.g. "first visit", no clinical info
  created_at, updated_at
  -- UNIQUE INDEX (account_id, starts_at) WHERE status IN ('confirmed','completed') -- prevent double-booking

appointment_state_events                   # Immutable audit trail of state transitions
  id, appointment_id, account_id
  from_status, to_status
  actor_user_id (nullable; null = client/system)
  reason (text)
  occurred_at

soap_notes
  id, account_id, appointment_id (unique)
  encrypted_data (bytea)                   # PHI: subjective/objective/assessment/plan
  created_at, updated_at

checkouts
  id, account_id, appointment_id (unique)
  cost_cents, discount_code_id (nullable), discount_cents
  tip_cents, paid_cents, balance_cents
  payment_method (text)                    # Free-text: cash, venmo, square_external
  completed_at

discount_codes
  id, account_id, code (unique per account)
  kind                                     # percent|fixed
  value_basis_points (for percent) / value_cents (for fixed)
  usage_cap (nullable), times_used
  expires_at (nullable), is_active
  is_default                               # Marks seeded F&F / FR / MP codes

reminders
  id, account_id, appointment_id
  channel                                  # email|sms (sms in V1.1)
  scheduled_at, offset_minutes
  status                                   # scheduled|sent|skipped|failed
  sent_at, error_message

reviews
  id, account_id, appointment_id, client_id
  rating (1..5), encrypted_comment (bytea, optional)
  is_public (bool, default false)          # V1: always false
  submitted_at, token_id

review_tokens
  id, account_id, appointment_id, hmac_signature
  expires_at, consumed_at

referral_settings
  account_id (pk), points_per_referral (int), updated_at

referral_events                            # Immutable log
  id, account_id, referrer_client_id, referred_client_id
  triggered_appointment_id, points_awarded, occurred_at

referral_redemptions
  id, account_id, client_id, service_id, points_spent, appointment_id, occurred_at

calendar_connections
  id, account_id, provider (google), provider_account_email
  encrypted_refresh_token (bytea)
  expires_at, last_sync_at, sync_status, consecutive_failures
  ical_signed_token                        # For iCal feed URL

csv_imports
  id, account_id, kind (clients|appointments)
  source_filename, row_count_attempted, row_count_succeeded, row_count_failed
  status                                   # pending|running|completed|failed
  error_report (jsonb)
  started_at, completed_at

audit_log                                  # Partitioned by month
  id, account_id, actor_user_id (nullable)
  action                                   # phi.read|phi.write|auth.login|...
  resource_type, resource_id
  ip_address, user_agent
  occurred_at
```

### 4.2 PHI-tagged fields (encrypted via envelope encryption)

| Table | Field | Reason |
|---|---|---|
| `clients` | `encrypted_notes` | Practitioner free notes may contain medical detail |
| `intake_submissions` | `encrypted_data` | Full intake history |
| `soap_notes` | `encrypted_data` | Treatment notes |
| `reviews` | `encrypted_comment` | May mention treatment specifics |

`clients.name`, `clients.email`, `clients.phone` are PII but not PHI — encrypted at rest by Supabase disk encryption, queryable for search. Per-tenant key encryption of these is a V2 hardening item.

### 4.3 Indexing strategy (key ones)

```
clients          INDEX (account_id, soft_deleted_at) INCLUDE (name)
appointments     INDEX (account_id, starts_at)
appointments     UNIQUE INDEX (account_id, starts_at) WHERE status IN ('confirmed','completed')
appointments     INDEX (account_id, status, status_expires_at) WHERE status IN ('requested','countered')
reminders        INDEX (status, scheduled_at) WHERE status = 'scheduled'
audit_log        Partitioned by occurred_at month
```

### 4.4 Booking request state machine

```
                    ┌────────────────────────────────────────────────┐
                    │  (public booking page POST)                    │
                    ▼                                                │
              ┌───────────┐                                          │
              │ requested │──┐                                       │
              └───────────┘  │                                       │
                  │     │    │                                       │
       confirm    │     │    │ decline                               │
                  ▼     ▼    ▼                                       │
            ┌─────────┐ ┌─────────┐ ┌──────────┐                     │
            │confirmed│ │countered│ │ declined │                     │
            └─────────┘ └─────────┘ └──────────┘                     │
                  │           │                                      │
                  │       ┌───┴────┐                                 │
                  │       │        │                                 │
                  │   accept    decline                              │
                  │       │        │                                 │
                  │       ▼        ▼                                 │
                  │  ┌─────────┐ ┌──────────┐                        │
                  │  │confirmed│ │ declined │                        │
                  │  └────┬────┘ └──────────┘                        │
                  │       │                                          │
                  └───────┤  (post-appointment, practitioner action) │
                          ▼                                          │
                  ┌─────────────────────┐                            │
                  │ completed | cancelled | no_show │                │
                  └─────────────────────────────────┘                │
                                                                     │
        auto-expiry job (Inngest, runs every 15 min):                │
        - requested  + 48h  → expired                                │
        - countered  + 72h  → expired ─────────────────────────────►─┘
```

State transitions are validated server-side in `packages/core/booking/state-machine.ts`. Every transition writes a row to `appointment_state_events`.

---

## 5. Security model

### 5.1 Defense in depth

1. **Network:** Vercel + Cloudflare DDoS protection. WAF rules for public booking endpoints.
2. **Application authz:** Every Server Action and Route Handler checks `accountId === session.accountId` via a shared helper in `lib/db/scoped.ts`. No raw Drizzle queries in route code — only through scoped helpers.
3. **Database RLS:** Supabase RLS policies as backstop. Every PHI table has a policy `account_id = current_account_id()` that derives the account from the JWT. Even if app code has a bug, RLS prevents cross-tenant reads.
4. **Field-level encryption:** PHI fields encrypted with per-tenant DEKs (§2.10). A SQL-only data leak yields ciphertext.
5. **Audit:** Every PHI read/write writes an `audit_log` row. Log is partitioned by month and archived to S3 with object-lock for tamper evidence.

### 5.2 Authentication flow

```
1. Practitioner enters email
2. Supabase Auth sends magic link via Postmark (custom template)
3. Click → exchange code for JWT → set httpOnly cookie
4. Middleware validates JWT on every (practitioner) route
5. Session lasts 30 days with sliding refresh
6. Optional TOTP MFA enrollment via Supabase Auth's built-in flow
```

### 5.3 Tokenized public links (intake, counter, review)

- HMAC-SHA256 signed with a per-environment secret rotated annually
- Payload: `{ accountId, clientId, purpose, expiresAt, nonce }`
- Lookup table (`intake_tokens`, `review_tokens`, counter via `appointments.counter_token`) tracks `consumed_at` for single-use enforcement
- Expiry: intake 30 days, counter 72 hours, review 14 days

### 5.4 Public booking page rate limits

- Upstash Redis sliding window: 5 requests / IP / minute, 20 requests / IP / hour
- Per-email cap to prevent practitioner spam: 3 requests / email / day per handle
- Cloudflare Turnstile challenge added when an IP exceeds threshold

### 5.5 Audit log fields

```
{ id, account_id, actor_user_id, actor_type ('practitioner'|'client'|'system'),
  action ('phi.read'|'phi.write'|'auth.login'|'auth.logout'|'csv.import.started'|...),
  resource_type, resource_id, ip_address, user_agent,
  request_id, occurred_at }
```

Retention: ≥ 6 years. Hot in Postgres for 90 days, then archived to S3 with object-lock + retrieval via Athena.

### 5.6 PHI in logs and errors — NEVER

- Structured logging via Axiom; a redaction middleware strips fields tagged `@phi` before send.
- Sentry: server-side `beforeSend` hook strips `intake`, `soap`, `notes` from any context object. PR-time linter forbids `console.log` of objects from PHI-marked tables.
- Stack traces never include PHI variables because field-level encryption keeps them as opaque bytes outside of explicit decryption scopes.

### 5.7 Backup and disaster recovery

- Supabase Pro: daily encrypted backups + 7-day PITR. Upgrade to higher tier for 30-day PITR at GA.
- Quarterly restore drill into a staging project.
- KMS keys: rotation annual; backed by AWS's own multi-region key durability.

---

## 6. Scalability considerations

V1 target: ~1,000 practitioners × 50 clients × 100 appts/month = ~5M appointments/year, ~5M reminder events/year. **Postgres on Supabase Pro handles this trivially.** Notes for the 10x growth path:

| Bottleneck | Mitigation |
|---|---|
| `audit_log` table size | Partitioned monthly; archive >90d to S3 |
| Reminder cron query | Index on `(status, scheduled_at) WHERE status='scheduled'`; Inngest fan-out for sending |
| Public booking page traffic spikes | ISR with on-demand revalidation when service menu changes; edge cache `/[handle]` |
| Reports query cost | Materialized view per account, refreshed nightly + on-demand via Inngest |
| Image/file uploads | Supabase Storage with CDN; signed URLs for intake attachments |
| Calendar sync API quota | Inngest queue with concurrency limit per Google account; backoff on quota errors |

We do **not** prematurely optimize for multi-region or sharding. Single US region (`us-east-1`) is correct for V1 and likely through 10,000+ accounts.

---

## 7. Mobile reuse strategy

**V1:** PWA-ready Next.js. Manifest, service worker for offline calendar read, install prompt on mobile. The practitioner UI is designed phone-first — buttons sized for thumbs, primary actions reachable one-handed, dense calendar reflows to single-column on small screens.

**V2 (React Native via Expo):**
- **Reused unchanged:** `packages/core` (domain logic), `packages/db` types (via shared API contracts), `packages/crypto`, `packages/auth`.
- **Reused with adapters:** `packages/ui` — Tailwind classes don't port directly; we'd either adopt NativeWind or rewrite the dozen-or-so primitives as RN components. Honest: this is the rewrite cost we accept for using shadcn on web.
- **Auth:** Supabase RN SDK shares sessions via deep link.
- **API:** When we ship mobile, this is the moment we add tRPC at `/api/trpc` so the RN app has a typed contract. Existing web continues to use Server Actions; new mobile-only endpoints go via tRPC.

**Why not React Native from day one?** Web is where solo practitioners live for setup, reporting, and CSV import. Phone-during-session use is browser-good-enough until we have product-market fit signal that justifies native investment.

---

## 8. Development environment

- **Local dev:** Docker Compose with Postgres + Mailpit (catches outgoing email) + LocalStack KMS (or AWS KMS dev key). Inngest runs in-process via `inngest dev`.
- **Seed data:** `pnpm db:seed` creates a demo practitioner with realistic clients/services/appointments.
- **Test data factories:** in `packages/db/seed/factories.ts` for unit + e2e tests.
- **Type-checked tests:** Vitest for unit, Playwright for e2e (booking-page happy path, reminder fires, CSV import).

---

## 9. CI/CD

- **GitHub Actions:**
  - On PR: lint (ESLint + Prettier), typecheck (`tsc --noEmit`), test (Vitest), build (Turbo).
  - On PR: Vercel preview deploy + Supabase branch DB.
  - On merge to `main`: Vercel production deploy + Drizzle migrate-deploy (with manual approval gate).
- **Drizzle migrations:** generated locally, committed, reviewed in PR, applied in CI with `drizzle-kit migrate`.
- **No direct prod DB access** from developer machines — only via Supabase dashboard with audit logging.

---

## 10. Open architectural questions

1. **Vercel Pro vs Enterprise at GA** — decide when we're 60 days from signing the first BAA, not before.
2. **CSV parser library** — `papaparse` (battle-tested, browser+node) vs `csv-parse` (node-native, faster). Lean Papa for V1.
3. **Calendar conflict resolution** for one-way push when practitioner edits an event directly in Google Calendar — V1 behavior: detect drift on next sync, surface a "Roomwell and Google disagree about this event" banner, let practitioner pick which side wins. Doc this rather than auto-resolve.
4. **Per-tenant KEK vs single-environment KEK** — V1 uses one environment-wide KEK that wraps per-account DEKs. Per-account KEK is a hardening item if a large customer demands true crypto-shredding.
5. **Search** — Postgres trigram on `clients.name` is fine for V1 (small per-tenant data). pgvector / typesense never needed at this scale.

---

*End of ARCHITECTURE v0.1.*
