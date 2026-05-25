# Marina Operations App

A Rails 8 monolith that connects boat owners with marina staff (managers and
helpers) to coordinate boat services — launches, cover removal, fueling, and
miscellaneous on-water requests. Built from `PLAN.html`.

## Stack

| Component        | Choice |
|------------------|--------|
| Framework        | Rails 8.1 |
| Frontend         | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| Real-time        | ActionCable on Solid Cable (DB-backed — no Redis required) |
| Background jobs  | Solid Queue (DB-backed — no Redis required) |
| Database         | PostgreSQL |
| Email            | Resend |
| SMS              | Quo (formerly OpenPhone) |
| Hosting          | Render.com via `render.yaml` |

> **Note**: `PLAN.html` specified Sidekiq + Redis. This implementation uses
> Solid Queue / Solid Cable instead — the Rails 8 defaults — to eliminate the
> Redis dependency. Swap in Sidekiq later if you need higher job throughput.

## Local development

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev   # starts puma + tailwind watcher
```

Then visit http://localhost:3000/login. In development, the login page shows
a **Dev quick-login** panel with one-click buttons for the three seeded
roles — no magic-link copy/paste needed:

| Button   | User                      | Lands on    | Notes |
|----------|---------------------------|-------------|-------|
| Manager  | `manager@example.com`     | `/dashboard` | Full `/admin/*` access |
| Helper   | `helper@example.com`      | `/dashboard` | No admin (gets 403) |
| Customer | `customer@example.com`    | `/` (My Boats) | Seeded with 2 boats — one wet at Browns Bay, one dry at Maxwell — so you can submit a request right away |

The dev panel and `POST /dev/login` are both gated by `Rails.env.development?`
on the server, and the route isn't defined outside development. Override the
manager email with `SEED_MANAGER_EMAIL=`.

To exercise the real auth flow instead, enter an email/phone — since no
`RESEND_API_KEY` is set, the magic link is printed to the Rails log; copy it
into your browser.

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│                    Render.com                        │
│  ┌──────────────────────────────────────────────┐   │
│  │  Rails 8 Monolith (one web service)          │   │
│  │  Puma + Hotwire + Tailwind + ActionCable     │   │
│  │  Solid Queue runs inside Puma via plugin     │   │
│  └────────────────────┬─────────────────────────┘   │
│                       │                             │
│  ┌────────────────────▼─────────────────────────┐   │
│  │ PostgreSQL (single DB, basic-1gb)            │   │
│  │ app tables + solid_queue/cache/cable tables  │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
  Resend (email) · Quo (SMS) — both with webhooks
```

## Domain model

- `Organization` — top-level tenant (one in v1).
- `Location` + `LocationHour` + `Slip` — physical sites and capacity.
- `User` (role: manager | helper | customer) — passwordless login.
- `AuthToken` — magic links and 6-digit SMS codes.
- `Session` — DB-backed sessions, rolling 30d / absolute 60d, supports
  "Sign out everywhere".
- `Boat` (owner → User, location, optional slip, storage_type).
- `RequestType` — **configurable per org**, with `applicable_storage_types[]`,
  icon, color, sort order, optional required description.
- `Request` — `to_do → in_progress → completed`, `to_do → cancelled`,
  `in_progress → to_do` (unstart). Completion requires `assigned_to`.
- `RequestNote` — public (visible to customer) or private (staff only).
- `Notification` — outbox row; channel = email | sms; tracked through
  delivered / bounced / failed.
- `AuditLog` — append-only, polymorphic on `auditable_type`.

## Key validations

- Requests require **≥ 1 hour lead time**, must be **within location hours**,
  must be **within 14 days**, and the request type must apply to the boat's
  storage type.
- Customers can only cancel while `to_do`. Once `completed`, a request is
  immutable (except for notes).
- Helpers can only modify their own assignments.

## Auth

Three sign-in paths, all going through `POST /auth/login`:

1. **Magic link** (default): submit `identifier=email@example.com` with no
   password → email link via `AuthMailer#magic_link`.
2. **SMS code**: submit `identifier=555-123-4567` → 6-digit Quo SMS →
   `POST /auth/verify` with `code=`.
3. **Password**: submit `identifier=email` + `password=...` → direct sign-in
   if the user has a `password_digest` set (the seeded admin does).

Other guarantees:

- Unknown identifiers always get the same generic response (no user enumeration).
- Wrong passwords always get the same generic "incorrect" alert, with a dummy
  bcrypt cost burned to soak timing differences.
- Rate limits via `Rack::Attack`: 5/hour per identifier, 20/hour per IP for
  `/auth/login`; 60/hour per IP for `/auth/verify`.
- Sessions: 30-day rolling, 60-day absolute, HttpOnly + Secure + SameSite=Lax,
  DB-backed so "Sign out everywhere" can revoke them all at once.

## Notifications

Triggered events and default channels:

| Event              | Recipient | Default channels |
|--------------------|-----------|------------------|
| `request_submitted` | Customer | email |
| `request_started`   | Customer | email |
| `request_completed` | Customer | email + sms |
| `request_cancelled` | Customer | email + sms |
| `public_note_added` | Customer | email |
| `request_assigned`  | Helper   | email |

- SMS is throttled to 8am–9pm in the location timezone.
- Webhooks: `POST /webhooks/resend`, `POST /webhooks/quo`. The Quo webhook
  honors `STOP/UNSUBSCRIBE/QUIT/CANCEL/END` by disabling SMS preferences for
  the originating phone.

## Real-time

- `DashboardChannel` is scoped per organization. The dashboard stream Stimulus
  controller subscribes and reloads on any received event — simple and
  drift-free for MVP. Per-card Turbo Stream broadcasts can replace this when
  more granular updates are needed.

## Render deployment

### One-time setup

1. Push this repo to GitHub.
2. In Render, **New → Blueprint** and point it at `render.yaml`. Render will
   provision a single Postgres database and a single web service. Background
   jobs (Solid Queue) run inside the web service via the Puma plugin — no
   separate worker dyno.
3. Set the secret env vars in the dashboard (everything marked `sync: false`
   in `render.yaml`):

   | Variable                | Required? | Notes                                                                 |
   |-------------------------|-----------|-----------------------------------------------------------------------|
   | `RAILS_MASTER_KEY`      | **Yes**   | The contents of your local `config/master.key`. Decrypts credentials. |
   | `APP_HOST`              | optional  | Custom domain (e.g. `marina.example.com`). Defaults to the onrender.com URL. |
   | `RESEND_API_KEY`        | for email | From [resend.com](https://resend.com) — magic links won't deliver without it. |
   | `MAIL_FROM`             | for email | Verified sender address on your Resend account.                       |
   | `RESEND_WEBHOOK_SECRET` | optional  | If set, the `/webhooks/resend` endpoint requires `X-Webhook-Secret`.  |
   | `QUO_API_KEY`           | for SMS   | From [quo.com](https://www.quo.com) → Settings → API keys.            |
   | `QUO_FROM`              | for SMS   | Either E.164 number (`+15555551234`) you own in Quo, or a Quo `PN…` id.|

4. Render auto-generates `SECRET_KEY_BASE` and `SEED_MANAGER_PASSWORD` (both
   listed with `generateValue: true` in `render.yaml`) — you don't set those
   yourself.
5. Hit **Apply**. Render builds the image, runs `./bin/render-build` which
   migrates the database and runs the (idempotent) seed.

### First sign-in as admin

The seed creates a manager user with:

- **Email**: `northshoremarinaapp@gmail.com` (override via `SEED_MANAGER_EMAIL`)
- **Password**: the value Render generated for `SEED_MANAGER_PASSWORD`

To retrieve the password, in the Render dashboard go to the `marina-web` service
→ **Environment** → click the eye icon next to `SEED_MANAGER_PASSWORD`. Copy it
into a password manager — that's the only place it persists.

Then visit `https://<your-app>.onrender.com/login`, enter the email + password,
and you're in. Magic links and SMS codes work in parallel for everyone else.

### Rotating the admin password

Either:

- Change `SEED_MANAGER_PASSWORD` in the Render dashboard and redeploy — the
  seed will adopt the new value (idempotent), or
- Sign in as the admin and use a Rails console one-liner via Render's shell:
  `User.find_by(email: "northshoremarinaapp@gmail.com").update!(password: "new_pw")`.

### Subsequent deploys

`./bin/render-build` runs `db:prepare` and `db:seed` every deploy. The seed is
idempotent: it won't overwrite the admin's password unless you've changed
`SEED_MANAGER_PASSWORD`, and won't duplicate locations, slips, request types,
or dev users (which are skipped in production anyway).

## Running the tests

```bash
bin/rails db:test:prepare
bundle exec rspec
```

The suite covers model invariants (validations, state machine), authentication
(magic link, SMS code, expiry), and role authorization (customer vs manager vs
unauthenticated).

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/login` · POST `/auth/login` · GET `/auth/check` | Login UI |
| GET/POST | `/auth/verify` | Verify magic link or SMS code |
| DELETE | `/logout` · POST `/logout/all` | Sign out (everywhere) |
| GET | `/` | Customer home (My Boats) — staff redirected to `/dashboard` |
| GET | `/boats/:id` | Boat detail |
| GET/POST | `/requests` · `/requests/new` · `/requests/:id` | Customer & staff request views |
| PATCH | `/requests/:id/status?to=` | Staff transitions |
| PATCH | `/requests/:id/assign` | Staff assignment |
| POST | `/requests/:id/cancel` · `/requests/:id/note` | Cancel & comment |
| GET | `/dashboard` · `/dashboard/day` · `/dashboard/week` | Staff views |
| GET | `/admin/*` | Manager-only CRUD (customers, boats, locations, slips, request types, staff) |
| GET | `/locations/:id/availability?date=` | JSON slot availability |
| POST | `/webhooks/resend` · `/webhooks/quo` | Delivery webhooks |

## What's *not* in v1 (deferred)

Hard capacity caps · photo upload on completion · bulk messaging · recurring
requests · co-owner accounts · payment integration · native apps · multi-tenant
SaaS · per-date hour overrides (holidays).
