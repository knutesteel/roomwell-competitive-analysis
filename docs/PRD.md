# Roomwell — Product Requirements Document (V1)

**Status:** Draft v0.2 · 2026-05-19
**Source:** Founder interview, Knute Steel
**Repo note:** These planning docs live in `roomwell-competitive-analysis/docs/` temporarily. They migrate to the new private product repo once it is created.

---

## 1. Vision

The simplest scheduling and client-management tool for solo wellness practitioners — lightweight where competitors are bloated, beautiful where they are clinical, and designed to run a one-chair business from a phone.

**Why now:** The weekly competitive listening in this repo shows solo practitioners abandoning Vagaro and Mindbody for being "salon-shaped," and gravitating to Jane / ClinicSense / Noterro. There is a clean gap below those — a *minimal* clinical-grade tool that does not punish a solo for being solo.

---

## 2. Users / ICP

- **Primary:** US-based solo massage therapists running a single-chair practice
- **Secondary (via vertical toggles):** solo aestheticians, hair stylists, barbers
- **Explicit non-users:** multi-staff salons, clinics doing insurance billing, retail chains

---

## 3. Jobs to be done

1. Book and track appointments without paper, primarily from a phone
2. Keep client history and treatment notes in one searchable place
3. Reduce no-shows via automated reminders
4. Capture revenue, tips, and balance per visit without running a real POS
5. Generate repeat business via referrals and rewards
6. Show up professionally to new clients (booking page, intake, follow-up)

---

## 4. Representative user stories

- *As a practitioner,* I add a new client and capture intake in under 2 minutes.
- *As a practitioner,* I tap a calendar slot, pick a client + service, and the appointment is booked.
- *As a practitioner,* I receive online booking *requests* I can confirm, counter (propose a different time), or decline.
- *As a practitioner,* my SOAP note attaches to the completed appointment record automatically.
- *As a practitioner,* my Google Calendar shows every Roomwell appointment within a minute.
- *As a practitioner,* a 24-hour email reminder fires automatically; I can also send one manually.
- *As a practitioner,* I import my existing clients and historical appointments from a CSV during onboarding.
- *As a practitioner,* I have a personal booking page (`roomwell.com/[handle]`) and a custom domain later.
- *As a client,* I request a booking online without creating an account, and complete intake via a tokenized email link.
- *As a client,* I receive the practitioner's counter-offer (different time) and accept or decline in one tap.
- *As a practitioner,* my month-end report shows revenue, tips, no-shows, referrals — date-rangeable.

---

## 5. Feature list — V1 scope

| # | Surface | Feature | Free (≤10 clients) | Paid (unlimited) |
|---|---|---|---|---|
| 1 | Onboarding | Signup, vertical selection, business profile | ✓ | ✓ |
| 2 | Onboarding | **CSV import** of clients + historical appointments | ✓ | ✓ |
| 3 | Auth | Magic-link primary, email/password fallback, optional MFA | ✓ | ✓ |
| 4 | Clients | CRUD, contact + intake (vertical-aware), SOAP, referral graph | ✓ ≤10 clients | unlimited |
| 5 | Services | Service menu CRUD with price + duration | ✓ | ✓ |
| 6 | Scheduling | Week (default) / day / month views; cancel; no-show | ✓ | ✓ |
| 7 | Public booking | Per-practitioner page with handle, availability, **request flow** | ✓ | ✓ |
| 8 | Booking requests | Confirm / counter / decline + auto-expire + auto-confirm toggle | ✓ | ✓ |
| 9 | Reminders | Email reminders (auto + manual, 24h + custom) | ✓ email | + SMS *(V1.1)* |
| 10 | Calendar sync | One-way push to Google Calendar; iCal feed | ✓ | ✓ |
| 11 | Discounts | Code CRUD + seeded F&F 20%, First Responder 15%, Medical Pro 10% | ✓ | ✓ |
| 12 | Checkout | Bookkeeping only: cost, discount, tip, paid, balance, SOAP attach | ✓ | ✓ |
| 13 | Reports | Revenue + tips + per-client summary, default current month | — | ✓ |
| 14 | Referrals | Points-per-referral + redeem-for-service rules | ✓ | ✓ |
| 15 | Reviews | Client-submitted rating + review (private to practitioner V1) | ✓ | ✓ |

---

## 6. Functional requirements (highlights)

### 6.1 Vertical toggle
- Chosen at signup, switchable later with warning on field loss.
- SOAP notes and medical-intake fields hidden on `hair` / `barber` by default.

### 6.2 Public booking page + request workflow
- Unique slug per practitioner (`roomwell.com/[handle]`), shows service menu and available slots.
- Client submits contact + service + slot → creates a **booking request** in state `requested`.
- Practitioner actions on a request:
  - **Confirm** → state `confirmed`, client receives confirmation email, calendar slot booked, appears on calendar.
  - **Counter** → practitioner proposes an alternate slot, state `countered`, client receives email with accept/decline links (tokenized, single-use, 72-hour expiry).
  - **Decline** → state `declined`, client receives polite decline email with rebook CTA.
- Client actions on a counter:
  - **Accept** → state `confirmed`.
  - **Decline** → state `declined`.
- **Soft hold:** the requested slot is held against double-booking for 24 hours by default (practitioner-configurable).
- **Auto-expire:** if a request sits in `requested` or `countered` longer than 48 hours (practitioner-configurable), it transitions to `expired` and the slot is released.
- **Auto-confirm toggle:** in settings, practitioner can opt to auto-confirm all online requests, bypassing the request flow.
- **State machine:** `requested → {confirmed | countered | declined | expired}`; `countered → {confirmed | declined | expired}`.

### 6.3 CSV import (V1, in-scope)
- Upload `.csv` for either **clients** or **appointments**; max 10 MB per file.
- Column-mapping UI: practitioner maps source columns to Roomwell fields; presets for common sources (Vagaro, Acuity, Square) selectable.
- Preview first 25 rows with validation errors highlighted before commit.
- Atomic batch import — all-or-nothing per file; rollback on error.
- Imported appointments are created with their original status (`completed`, `cancelled`, `no_show`); SOAP notes can be imported as a free-text note field.
- Uploaded raw CSVs are deleted after job completion; no retention.
- Import history visible in settings, with row counts and any skipped/failed records.

### 6.4 Intake forms
- Vertical-aware schema (full medical history for massage/aesthetics; lightweight contact-only for hair/barber).
- Tokenized email completion link; 30-day expiry; single-use.
- Forms versioned — completed forms preserve the version they were filled against.

### 6.5 Reminders
- Scheduled job runs every 5 minutes; per-appointment reminder ledger prevents duplicates if config changes.
- Default 24-hour-before email; practitioner can add additional reminders (e.g., 2-hour, 7-day) per service or per appointment.

### 6.6 Calendar sync
- Google OAuth with minimal `calendar.events` scope.
- iCal feed at a stable signed URL for Apple Calendar / Outlook.
- One-way push only — Google Calendar reflects Roomwell appointments; external events do **not** block Roomwell availability in V1.
- Sync failures surface a practitioner-visible "sync paused" banner with a one-click reconnect.

### 6.7 Discount codes
- Percentage or fixed-amount; optional usage cap; optional expiry date.
- Seeded codes: F&F (20%), First Responder (15%), Medical Pro (10%) — practitioner can edit or delete.

### 6.8 Checkout (bookkeeping only)
- Flow: cost → discount → subtotal → tip → paid → balance.
- SOAP note required to mark appointment `completed` for clinical verticals (massage, aesthetics).
- No card processing in V1 — practitioner records how the client paid (cash, Venmo, external Square, etc.) via free-text "payment method" field.

### 6.9 Reports
- Date-range picker, default current month.
- Revenue (services + tips = total), broken out by service and per client.
- No-shows count, referrals count, completed appointments count.
- CSV export.

### 6.10 Referrals
- Configurable: points per referred client's first completed appointment.
- Redemption catalog: practitioner sets points value per service.
- Client-level points ledger visible on client detail.

### 6.11 Reviews
- Client submits rating (1–5) + optional text after a completed appointment via tokenized link.
- **Private to practitioner in V1** — not displayed on the public booking page. Opt-in public display planned for V1.x.

---

## 7. Non-functional requirements

- **Performance:** practitioner dashboard interactive in <1 s on warm cache, <2.5 s cold; booking page LCP <2 s on 4G.
- **Mobile:** responsive + PWA-ready; practitioner UX is **phone-first**, not phone-tolerable.
- **Accessibility:** WCAG 2.1 AA.
- **Browser support:** last two versions of Chrome, Safari, Firefox, Edge.
- **Availability:** 99.9% SLO; public status page from day one.
- **Data residency:** US only.
- **Encryption:** TLS 1.3 in transit; AES-256 at rest; **field-level encryption for PHI** (intake answers, SOAP notes, attached files).
- **Audit logs:** every read/write to PHI logged with actor, IP, timestamp, record id; retained ≥ 6 years.
- **Backups:** encrypted, daily, 30-day point-in-time recovery; quarterly restore drill.
- **Logging:** PHI never appears in application logs; redaction middleware applied to all structured log calls.
- **Secrets:** managed via hosting platform env + Doppler or 1Password CLI for local dev.

---

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Multi-vertical scope blurs product focus | High | Med | Vertical toggle; design language stays massage-first |
| Public booking double-booking race | Med | High | DB uniqueness on `(practitioner, time_slot, status≠declined/expired)` + advisory lock during request creation |
| Free-tier abuse (sock-puppet clients) | Med | Med | 10-client hard cap; rate-limit booking-page POSTs by IP + email |
| HIPAA scope creep (clinic asks for BAA) | Med | Med | Public posture: "HIPAA-grade engineering, no BAA in V1" |
| Google Calendar token expiry / quota | Med | Med | Retry queue + sync-paused banner + reconnect flow |
| Email deliverability (reminders bouncing) | Med | High | SPF/DKIM/DMARC authenticated domain; Postmark for transactional |
| 10DLC delay for V1.1 SMS launch | High | Low | Begin registration in parallel during V1 build |
| Accidental client/appointment deletion | Low | High | Soft-delete for clients + appointments; 30-day trash |
| CSV import data corruption | Med | High | All-or-nothing batches; preview validation; per-row error report |

---

## 9. MVP cut line

**In V1 (must ship to beta):** items 1–15 in §5.

**Deferred to V1.x / V2 (not V1):**
- SMS reminders → V1.1 (paid-tier gated)
- Public-facing reviews on booking page → V1.x
- Client login portal → V1.2
- Stripe Connect payments + tipping rails → V2
- Gift certificates, prepay packages, subscription billing for clients → V2
- Email marketing / newsletters → V2
- iOS native app → V2
- Two-way calendar sync (external blocks Roomwell availability) → V2
- Multi-user / staff scheduling → V2+
- Insurance billing, superbills → out of scope
- Public marketplace / directory → out of scope

---

## 10. Technical constraints

- HIPAA-grade engineering with **no BAA signing in V1** — vendor selection must still favor BAA-capable providers for future state.
- US data residency end-to-end.
- Non-technical user audience: zero jargon in UI; no settings page deeper than two levels.
- Mobile-first practitioner UX; public booking page must hit Core Web Vitals "good" thresholds for SEO.

---

## 11. Compliance posture (V1)

- All HIPAA technical safeguards in place (encryption, audit, access, integrity, transmission).
- Public statement: *"Roomwell uses HIPAA-grade security practices. We do not currently sign Business Associate Agreements; consult your state's licensing requirements."*
- Privacy Policy + Terms of Service required at launch (counsel review pre-GA).
- Subprocessor list maintained publicly.

---

## 12. Success metrics

**Beta phase (leading indicators):**
- Activation: % of signups who add ≥1 client AND book ≥1 appointment in week 1 — target 60%+
- Week-4 retention of activated practitioners — target 70%+
- Time-to-first-appointment from signup — target <10 min median
- CSV import adoption: % of new signups who complete an import — target 30%+

**Post-launch (lagging):**
- Public booking conversion (page visit → confirmed booking)
- Reminder-to-show uplift vs no-reminder baseline
- Free → paid conversion at the 10-client ceiling — target ~15%
- NPS — target 50+

---

## 13. Open design questions (to resolve before / during build)

1. **Visual direction** — `roomwell_homepage_v1.html` lives on the founder's local machine. Push it to this branch (or paste contents) so product UI inherits the marketing-site design language.
2. **Practitioner URL scheme:** `roomwell.com/[handle]` for V1, subdomain support later. *(Recommendation locked unless objected.)*
3. **Time zones:** per-practitioner only in V1; per-client TZ deferred. *(Recommendation locked unless objected.)*
4. **Vertical toggle switchability** post-signup: switchable with field-loss warning. *(Recommendation locked unless objected.)*
5. **CSV import presets:** which competitor export formats matter most for day-one parity? Recommendation: Vagaro + Acuity + Square; add Mindbody / Jane in V1.x.
6. **Tech stack** — recommended in Phase 3 (Next.js + Supabase + Vercel + Postmark + Twilio later), with reasoning + alternatives.

---

*End of PRD v0.2.*
