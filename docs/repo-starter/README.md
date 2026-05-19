# Roomwell

The simplest scheduling and client management tool for solo wellness practitioners.

See `docs/` for product and architecture specifications. The single source of truth is:
- `docs/PRD.md` — product requirements
- `docs/ARCHITECTURE.md` — technical architecture
- `docs/ROADMAP.md` — milestones and build sequence

## Repository layout

```
roomwell-app/
├── apps/
│   └── web/         # Next.js 15 app (practitioner + public booking)
├── packages/
│   ├── db/          # Drizzle schema + migrations
│   ├── core/        # Domain logic (booking state machine, checkout math, …)
│   ├── crypto/      # PHI envelope encryption (AWS KMS)
│   ├── jobs/        # Inngest functions
│   ├── email/       # Postmark templates + sender
│   ├── auth/        # Supabase auth wrappers
│   ├── ui/          # Shared UI primitives
│   └── config/      # Shared tsconfig / eslint / tailwind bases
├── infra/           # IaC (later)
├── docs/            # Specifications + decisions
└── scripts/         # Dev helpers
```

## Prerequisites

- Node.js 20+
- pnpm 9+ (`corepack enable && corepack prepare pnpm@latest --activate`)
- A Supabase project (US region)
- An AWS account with KMS access (a dev key is fine to start)
- A Postmark account with a verified sending domain
- A Vercel account linked to this repo

## First-time setup

```bash
# 1. Install deps
pnpm install

# 2. Copy env template
cp .env.example .env.local
# Fill in Supabase URL/keys, KMS key id, Postmark token, etc.

# 3. Generate the Next.js app scaffold (one-time, only if apps/web is empty)
pnpm dlx create-next-app@latest apps/web \
  --typescript --tailwind --app --src-dir=false \
  --import-alias='@/*' --use-pnpm --eslint

# 4. Initialize packages (one-time)
pnpm dlx tsx scripts/init-packages.ts

# 5. Run database migrations
pnpm db:migrate

# 6. Seed local dev data
pnpm db:seed

# 7. Start dev server
pnpm dev
```

After step 7, open http://localhost:3000.

## Day-to-day commands

```bash
pnpm dev              # Run all apps in dev mode (Turborepo)
pnpm build            # Production build of everything
pnpm lint             # ESLint across the monorepo
pnpm typecheck        # tsc --noEmit across packages
pnpm test             # Vitest unit tests
pnpm test:e2e         # Playwright end-to-end tests
pnpm db:migrate       # Apply pending Drizzle migrations
pnpm db:generate      # Generate a new migration from schema diffs
pnpm db:studio        # Open Drizzle Studio
pnpm db:seed          # Seed local dev data
```

## How we work

- **Trunk-based.** All work merges into `main` via PR. No long-lived feature branches.
- **Every PR runs CI** — lint, typecheck, tests, build, migration check.
- **Vercel preview deploy per PR**, with a Supabase branch database for isolation.
- **Every schema change updates `docs/data-model.md`.**
- **Every PR touching `packages/crypto` requires a second reviewer.**
- **`packages/core` has no I/O dependencies** — pure domain logic, fully unit-tested.

## Security

- **No PHI in logs, ever.** The Axiom logger and Sentry both run PHI redaction. If you add a new PHI field, mark it `@phi` in the schema so the redaction middleware sees it.
- **All DB access goes through `lib/db/scoped.ts`** — never write raw Drizzle queries in route or action code. The ESLint rule enforces this.
- **Secrets live in Vercel / GitHub Actions secrets only.** Never commit a `.env.local`. The `.gitignore` should catch it, but if you're unsure, ask.
- **Field-level encryption** for PHI is in `packages/crypto`. See its README for the envelope encryption pattern and how to add a new encrypted field.

## See also

- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
