# Roomwell — V1 Roadmap, Milestones, and Build Sequence

**Status:** Draft v0.1 · 2026-05-19
**Companion to:** `docs/PRD.md` v0.2, `docs/ARCHITECTURE.md` v0.1
**Founder constraint:** No fixed launch date — "build it right." This roadmap is a *sequence*, not a calendar. Sprint lengths are suggested, not committed.

---

## 1. Guiding principles for the build

1. **Risk-first ordering.** The scariest unknowns get built first so we discover problems while there's time to react. The crypto package, the booking state machine, and double-booking concurrency are M0–M2, not M5.
2. **Ship the practitioner happy path end-to-end before adding surfaces.** A practitioner should be able to sign up, add a client, book an appointment, mark it complete, and record payment by end of M2 — even if booking pages, reminders, calendar sync, and reports aren't built yet.
3. **Internal dogfooding before any external user.** Founder + 1–2 friendly practitioners should use the product for real work no later than the end of M3.
4. **Vertical slices, not horizontal layers.** Build "clients" feature top-to-bottom (UI + actions + DB + RLS + audit + tests) before moving to "services." Avoid the trap of "all schemas done, all UI half-built."
5. **PHI handling is plumbing, not an epic.** The `packages/crypto` envelope-encryption pattern is solved once in M0 and reused by every PHI write thereafter. No "we'll wire up encryption later" tickets.

---

## 2. Milestones

Each milestone is gated on a working, demoable outcome — not on tickets-closed.

### M0 — Foundation *(suggested: 1–2 weeks)*
**Demo outcome:** Empty signed-in dashboard at `app.roomwell.com`, with a real account row in Postgres, all CI green, error tracking firing on a test error.

- ~~Create private repo, push initial scaffold~~ **Done** — `knutesteel/RoomwellAppClaudeCode` (commit `9dd36a6`)
- Monorepo scaffold: pnpm workspaces, Turborepo, shared `tsconfig`, ESLint, Prettier
- Next.js 15 App Router app at `apps/web`
- Tailwind CSS + shadcn/ui baseline + first dozen primitives
- Supabase project (US region), Drizzle scaffolding, first migration (accounts + users)
- AWS KMS dev key + `packages/crypto` skeleton with envelope encrypt/decrypt working in a unit test
- Auth: Supabase Auth integration, magic-link signup + login, custom Postmark template
- Practitioner shell layout, empty `/dashboard` page behind auth guard
- CI: lint, typecheck, vitest, build, Drizzle migration check
- Vercel project + preview deploys per PR + production env wired
- Sentry (errors), Axiom (logs), Vercel Web Vitals
- `.env.example`, secrets documented, no secrets in code

**Why first:** The crypto package and audit-log foundation must exist *before* any PHI table is added. Adding them after the fact is a 10x cost.

### M1 — Clients, services, intake *(suggested: 2 weeks)*
**Demo outcome:** Practitioner signs up, chooses vertical, sets up business profile, adds 5 clients (one via tokenized intake link from email), creates 3 service-menu items.

- Account/business profile setup wizard (signup → vertical → business info → done)
- Vertical toggle with field-loss warning on change
- Clients CRUD with soft-delete + 30-day trash view
- Encrypted `clients.notes` field through `packages/crypto`
- Intake form schema (versioned, vertical-aware) seeded for massage + aesthetics
- Tokenized intake email link flow (HMAC-signed token, expiry, single-use)
- Services CRUD (name, duration, price, optional points value)
- Discount codes CRUD with seeded F&F (20%), First Responder (15%), Medical Pro (10%)
- RLS policies live on every table touched
- Audit log writes for every PHI read/write
- Vitest unit tests for `packages/core` and `packages/crypto`

**Risk this resolves:** PHI encryption + audit + RLS are battle-tested by every CRUD operation in M1 before M2 piles more on.

### M2 — Scheduling + SOAP + checkout (internal-only) *(suggested: 2–3 weeks)*
**Demo outcome:** Practitioner manually books, completes, and checks out an appointment with a SOAP note. End-to-end happy path works on phone.

- Appointments data model + state machine in `packages/core/booking`
- Booking state machine validated server-side; every transition writes `appointment_state_events`
- Calendar UI: week (default), day, month views — phone-first
- Manual scheduling: tap slot → pick client → pick service → confirm
- Internal status transitions: cancel, no-show, complete
- SOAP note required to complete (clinical verticals)
- Checkout flow: cost → discount → tip → paid → balance → save
- Double-booking prevention: DB unique index + advisory lock during creation
- Phone-first UX QA — tested on real iPhone Safari + Android Chrome
- E2E test: signup → add client → book → complete → checkout

**Why M2 before public booking:** the internal scheduling flow is the foundation. The public booking page reuses 80% of this data model and UI primitives. Build the foundation once, then extend.

### M3 — Public booking + request flow *(suggested: 2–3 weeks)*
**Demo outcome:** A real prospective client books from `roomwell.com/[handle]`, practitioner counters with a different time, client accepts. Founder + 1–2 friendly practitioners begin internal dogfooding.

- Public booking page at `/[handle]` (SSR/ISR, edge-rendered)
- Availability calculation engine
- Request creation (unauthenticated)
- Soft-hold on requested slot (24h configurable)
- Booking-request inbox for practitioner
- Confirm / counter / decline UI
- Tokenized counter-accept/decline public page
- Auto-confirm toggle in settings
- Inngest job: state expiry (`requested` +48h, `countered` +72h → `expired`)
- Rate limiting via Upstash Redis (per-IP, per-email)
- Cloudflare Turnstile challenge on rate-limit threshold
- Reserved-handle list (admin, www, signup, etc.)

**Risk this resolves:** the request-flow state machine + concurrency. After M3, we know the hardest workflow is correct.

### M4 — Reminders + calendar sync *(suggested: 2 weeks)*
**Demo outcome:** Appointment booked today triggers an automatic 24h-before email; practitioner sees Roomwell appointments in their Google Calendar.

- Inngest setup: production project, function deployment via CI
- Reminder scheduling job: every 5 min, query for due reminders, send via Postmark
- Per-appointment reminder ledger (no duplicates if config changes mid-flight)
- Reminder configuration UI (default ladder + per-service overrides)
- Manual "send reminder now" button
- Google Calendar OAuth (offline access scope)
- One-way push: confirmed appointment → Google Calendar event
- iCal feed at `/api/ical/[signed_token].ics`
- Sync failure handling: `sync_paused` banner + reconnect flow
- Bounce/complaint handling via Postmark webhook

### M5 — Reports, reviews, CSV import *(suggested: 2 weeks)*
**Demo outcome:** End-of-month report shows accurate revenue, tips, no-shows, referrals. Practitioner imports 50 historical clients and 200 past appointments from a Vagaro export.

- Reports page: date-range picker (default current month), revenue/tips/no-show counts, per-client summary, CSV export
- Reviews: tokenized post-appointment email, submission page, private display on client detail
- Referrals: points-per-referral setting, points ledger, redemption against service catalog
- CSV import UI: upload, column mapping, preset for Vagaro/Acuity/Square, preview validation, atomic batch
- Inngest job: CSV import worker (parse → validate → batch insert → notify)
- Import history page

### M6 — Pre-launch hardening *(suggested: 2 weeks)*
**Demo outcome:** Closed beta launch readiness.

- Audit log archival to S3 with object-lock
- Quarterly backup restore drill (run once now to validate the procedure)
- External security review or pen test
- Privacy Policy + Terms of Service (counsel-reviewed)
- Subprocessor list page
- Status page (Statuspage.io or BetterStack)
- Performance budget enforcement in CI (Core Web Vitals on public booking page)
- Accessibility audit (axe-core in CI + manual NVDA/VoiceOver pass)
- Marketing-site CTA wiring (`roomwell.com` → signup)
- Free-tier hard cap enforcement (10 clients) with upgrade flow
- Stripe Billing for paid tier subscription (note: this is *practitioner* paying us, not client paying practitioner — that's deferred to V2)
- Closed beta invite system + waitlist gating

---

## 3. Build sequence — the order matters

```
M0 Foundation       →  M1 Clients/Services    →  M2 Scheduling/SOAP/Checkout
(crypto, audit,         (PHI plumbing            (state machine,
 auth, infra)            in practice)             double-booking,
                                                  internal happy path)
                                                       │
                                                       ▼
M6 Hardening        ←  M5 Reports/Reviews/CSV   ←  M4 Reminders/Calendar
(beta-ready)            (analytics, import)         (Inngest in earnest)
                            │
                            └─────────  ←  M3 Public Booking + Requests
                                          (the public surface)
```

**Why this order, not "ship features users see first":**

- The risky parts (crypto, audit, state machine, concurrency) are M0–M3.
- The features that are mostly "queries and a table" (reports, reviews) are M5 because they're low-risk and benefit from real data accumulated during M3 dogfooding.
- CSV import is M5 because it depends on every other table existing. Doing it earlier means rebuilding it after each schema change.
- Hardening is its own milestone because it's tempting to skip — it's not.

---

## 4. Technical backlog — risk-ordered epics

Each item is sized as **S/M/L/XL** by engineering effort. Sized assuming one senior full-stack engineer; halve for two.

| # | Epic | Milestone | Size | Risk | Notes |
|---|---|---|---|---|---|
| 1 | KMS envelope encryption package | M0 | M | High | Get this right once, reuse forever |
| 2 | Booking state machine + transitions | M2/M3 | M | High | Most subtle domain logic in the app |
| 3 | Double-booking concurrency | M2 | M | High | DB unique index + advisory lock |
| 4 | Google Calendar OAuth refresh lifecycle | M4 | M | High | Refresh token rotation, quota errors, broken-state UX |
| 5 | CSV import with rollback | M5 | L | Med | Long-running, multi-step, user-trust-critical |
| 6 | Audit log table + archival | M0/M6 | M | Med | Partition early, archive late |
| 7 | RLS policies + scoped query helpers | M0 | M | Med | Belt and suspenders for cross-tenant safety |
| 8 | Public booking page concurrency + rate limiting | M3 | M | Med | Upstash + Turnstile |
| 9 | Vertical toggle + field-loss handling | M1 | S | Low | Mostly UI + warning |
| 10 | Reminder ladder + ledger | M4 | M | Med | Idempotency under config changes |
| 11 | Reports + materialized aggregates | M5 | M | Low | Mostly queries; views if perf demands |
| 12 | Stripe Billing for practitioner subscription | M6 | M | Low | Standard Stripe; we charge practitioners |
| 13 | Email template system (React Email) | M0/M1 | S | Low | Reusable across reminders, intake, counters, reviews |
| 14 | PWA manifest + service worker | M6 | S | Low | Install prompt, offline calendar read |
| 15 | Privacy Policy + ToS pages | M6 | S | High (legal) | Counsel review required |
| 16 | External security review | M6 | S | Med | Either pen test firm or HackerOne-style |

### Cross-cutting (not milestone-bound)

- **Linting & forbidden patterns:** ESLint rules forbidding `console.log` of PHI-tagged tables, forbidding raw Drizzle queries outside `lib/db/scoped`, forbidding `any` in `packages/core`.
- **Documentation:** Every PR with a schema change updates `docs/data-model.md`. Every PR touching `packages/crypto` requires a second reviewer.
- **Performance budget:** booking page LCP <2s on simulated 4G in CI (Lighthouse-CI).
- **Accessibility:** axe-core in CI, blocking on serious violations.

---

## 5. What we are explicitly NOT building in V1

Repeating from the PRD because scope creep happens at build time, not planning time:

- ❌ SMS reminders (V1.1 paid feature; 10DLC registration starts during M4)
- ❌ Client login portal (V1.2)
- ❌ Stripe Connect for client→practitioner payments (V2)
- ❌ Gift certificates, prepay packages, subscriptions for clients (V2)
- ❌ Email marketing / newsletters (V2)
- ❌ Native iOS app (V2)
- ❌ Two-way calendar sync (V2)
- ❌ Multi-user / staff (V2+)
- ❌ Insurance billing (out of scope)
- ❌ Public marketplace / directory (out of scope)
- ❌ Public reviews on booking pages (V1.x)
- ❌ Custom domains for booking pages (V2)

**Anyone proposing to add one of these mid-build owes a written tradeoff doc.**

---

## 6. Beta readiness checklist (end of M6)

- [ ] Founder + 2 friendly practitioners have used the product for ≥4 weeks of real work
- [ ] Zero unresolved P0 bugs, ≤5 unresolved P1 bugs
- [ ] Backup restore drill passed (full DB restored to a staging project in <2h)
- [ ] External security review passed (or pen test report received with all High findings fixed)
- [ ] Privacy Policy + Terms of Service published, counsel-approved
- [ ] Subprocessor list page live
- [ ] Status page live
- [ ] Core Web Vitals "good" on `/[handle]` and `/dashboard`
- [ ] WCAG 2.1 AA audit clean (no serious axe violations)
- [ ] Audit log archival to S3 confirmed working
- [ ] Free-tier hard cap (10 clients) enforced + upgrade flow tested
- [ ] Stripe Billing live for paid tier
- [ ] Closed beta invite system live with waitlist on roomwell.com

---

## 7. V1.x and V2 roadmap shape (preview, not commitment)

**V1.1 (4–6 weeks post-beta):**
- SMS reminders (paid tier, 10DLC completed)
- Public reviews on booking page (opt-in)
- CSV import presets for Mindbody, Jane, Noterro
- Custom email template editing per practitioner

**V1.2 (8–12 weeks post-beta):**
- Client login portal: view past appointments, rebook, fill forms
- Two-way booking history visible to client (consent-gated)

**V2 (6+ months post-beta):**
- Stripe Connect: real card payments + tipping rails
- Gift certificates, prepay packages
- Subscription/membership for clients
- iOS native app via Expo + tRPC
- Two-way Google Calendar sync (busy blocks)
- Marketing email tooling

---

## 8. First two sprints — concrete tickets

If we want to skip "plan the plan" and start building, here are the first ~15 tickets for M0:

1. ~~Create private repo, push initial scaffold~~ **Done** — `knutesteel/RoomwellAppClaudeCode` (commit `9dd36a6`)
2. Wire pnpm workspaces + Turborepo, get `pnpm dev` running an empty Next.js app
3. Configure Tailwind + install initial shadcn primitives (button, input, label, card, dialog)
4. Connect Supabase project (US East), generate service-role + anon keys, store in Vercel + GH Actions secrets
5. Drizzle: init schema package, first migration (`accounts`, `users`), `pnpm db:migrate` works locally + in CI
6. AWS KMS: create dev KEK, set up `packages/crypto` with `encryptField` / `decryptField` + Vitest tests
7. Auth: Supabase magic-link flow, custom Postmark email template, `/signup` + `/login` pages
8. Practitioner layout shell with auth guard and empty `/dashboard`
9. CI workflow: lint + typecheck + test + build on PR
10. Vercel project: connect repo, preview deploys per PR, production env
11. Sentry: SDK install, `beforeSend` PHI redaction, test error event
12. Axiom: structured logger with PHI redaction middleware
13. `.env.example` + onboarding doc in repo README
14. `lib/db/scoped.ts` helper + ESLint rule forbidding raw Drizzle outside it
15. `docs/data-model.md` seeded with the initial schemas

After M0 ships green, we plan M1 in concrete tickets the same way.

---

*End of ROADMAP v0.1.*
