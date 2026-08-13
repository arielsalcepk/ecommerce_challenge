# Ecommerce Challenge

An enterprise-grade e-commerce catalog built with Elixir, Phoenix LiveView, and PostgreSQL: product CRUD, CSV import, search, and a purchase flow with a faked payment step.

## Tech stack

- **Elixir / Phoenix 1.8 / LiveView** — the entire UI (CRUD forms, search, CSV upload, purchase) is server-rendered LiveView; no separate frontend framework or API layer needed.
- **PostgreSQL** — the required local database.
- **Tailwind CSS + daisyUI** — daisyUI ships with `phx.new` 1.8 by default; used here for pre-styled components (buttons, alerts, cards) to get a polished look within the time available, rather than hand-writing every component's CSS.
- **NimbleCSV** — CSV parsing (RFC4180-correct quoting/escaping).
- **Docker / Docker Compose** — production release container + local dev orchestration.

## Setup

### Option A — Docker (recommended, closest to how this would actually run)

```bash
cp .env.example .env
# edit .env: set SECRET_KEY_BASE to the output of `mix phx.gen.secret`
# (or `openssl rand -base64 48` if you don't have Elixir installed locally)

docker compose up --build
```

Migrations run automatically on container start. Visit [http://localhost:4000/products](http://localhost:4000/products).

### Option B — Native (`mix phx.server`)

Requires Elixir 1.17+ and a local or containerized Postgres.

```bash
docker compose up -d db      # just the database, or run your own local Postgres
mix setup                    # deps.get, ecto.create, ecto.migrate
mix phx.server
```

Visit [http://localhost:4000/products](http://localhost:4000/products).

### Running tests

```bash
mix test              # full suite
mix test --cover      # coverage report (threshold: 80%)
mix format --check-formatted
```

## The provided example CSV

Downloaded **August 10, 2026** (from the recruiter email attachment, verified via the file's actual mtime — not guessed). It's deliberately messy: a `$`-prefixed price, a literal `"free"` price, negative stock, a blank name, a whitespace-only name, a blank category, two fully-blank rows, duplicate SKUs with updated data across rows, an embedded `<script>` tag, a SQL-injection-style string, and embedded commas/quotes. Handling this correctly (rather than just "not crashing on it") is what most of the design decisions below are about.

## Decisions and alternatives considered

| Area | Decision | Why / alternative considered |
|---|---|---|
| Purchase flow | Single-product "Buy Now" + quantity, no cart | A cart needs persistent multi-item state, multi-item checkout UI, and an atomic stock decrement across N products. Scoped out given the timeline; noted here as the natural next step. |
| CSV: duplicate SKU | **Upsert by SKU** (insert new, update existing) | SKU is the natural identity of a product. A real catalog is maintained via recurring re-uploads with updated prices/stock for existing SKUs — that's the actual point of a repeatable import feature. Rejecting duplicates would make CSV import "new products only" and defeat that purpose. The sample file's repeated-SKU-with-updated-data rows confirm this reading. |
| CSV: negative/unparseable stock | **Reject the row**, report why | Stock is a physical count; negative is never a valid real state, only ever a data error. Silently clamping to 0 doesn't fix bad data, it guesses — and could turn a real, sellable product into a false "out of stock." Rejecting puts it in front of a human who can check the source file. |
| CSV: price = `"free"` or unparseable | **Reject the row** | A real $0 item would be exported as `0`/`0.00`; free text in a decimal column is ambiguous, and given this file also contains XSS/SQL-injection test rows, it reads as a malformed-input probe rather than an intentional price. |
| CSV: price = `"$1,299.99"` | **Normalize**: strip `$`/commas before parsing | Unambiguous — safe to normalize rather than reject. |
| CSV: blank category | Default to `"Uncategorized"` | Category is a soft/cosmetic field, unlike price/stock. Rejecting the row would drop an otherwise-good, sellable product over a non-critical field. |
| Category field type | Plain `:string`, not a hard enum or separate table | The CSV's categories are open-ended and one row is blank — a fixed enum can't absorb novel or blank values without rejecting the row, and would need a code change + deploy to add a new category. The real production answer is a separate `categories` table with a `category_id` FK (admin-managed, referential integrity, no typo-duplication) — noted here as the correct next step, not built given the timeline. |
| CSV insert strategy | Per-row `Repo.insert` with `on_conflict`, not bulk `insert_all` | A single `insert_all` statement can't target the same conflict key (SKU) twice in one statement — Postgres errors, and this file has repeated SKUs. Per-row inserts sidestep this and give natural per-row error isolation for the import report. Bulk insert is a scale optimization worth revisiting at real volume (tens of thousands of rows), not needed here. |
| XSS / SQL-injection test rows | Store as plain text as-is; no import-time sanitization | The correct control lives at the query and render layer, not ingestion. Ecto changesets always use parameterized queries (the SQL-injection row is stored and retrieved as inert text with no side effects), and Phoenix's HEEx templates auto-escape all output by default (the `<script>` row renders as visible literal text, confirmed manually — it does not execute). Sanitizing at import time would risk corrupting legitimate data for no added safety. |
| Search | Free-text search only (name/sku/description), no category filter dropdown | "Search for Products" is the explicitly named requirement; a filter dropdown is an enhancement on top of it, cut to protect time for CSV/purchase correctness and tests. |
| Pagination | DB-level (`LIMIT`/`OFFSET` in the query) | Only the current page's rows are ever fetched from Postgres — never load-all-then-filter in the app. |
| Price/stock integrity | **Both** a DB check constraint and a changeset `check_constraint/3` | The DB constraint is the real, unbypassable guarantee. The changeset-level declaration isn't a second guarantee — it translates a DB rejection into a normal, friendly form error instead of a raw `Ecto.ConstraintError` crash. Different jobs, not redundant. |
| Auth | None | Neither the brief nor the CSV spec mentions accounts or roles — building it would be scope creep, not a considered cut. Noted here as a known gap for a production deployment. |

## Security notes

The two "attack" rows in the sample CSV (`<script>alert('xss')</script>` as a product name, `Robert'); DROP TABLE products;--` as another) are handled by *not* being special-cased:

- **SQL injection**: every query in this app goes through Ecto's query DSL or changesets, which always bind parameters — there is no string-interpolated SQL anywhere. Verified manually: importing the SQL-injection row does not affect the `products` table (row count matches expectations before/after).
- **XSS**: Phoenix's HEEx templates escape all interpolated content by default. Verified manually in the browser: the `<script>` row renders as visible text in the product table, not as an executed script.

## What I'd add with more time

- A shopping cart / multi-item checkout.
- A proper `categories` table with admin-managed entries instead of a free-text column.
- Authentication and role-based access for the admin CRUD surface.
- Bulk `insert_all`-based CSV import for very large files (with per-batch SKU de-duplication).
- Trigram (`pg_trgm`) indexes if search needs to scale past a small catalog.

## AI usage disclosure

This project was built in collaboration with Claude (Anthropic). I used it the way the closing note in the brief describes — as something to direct against my own judgment, not something to accept output from wholesale. Most of the decisions in the table above only landed where they did after I pushed on the reasoning behind them:

- On category modeling, I asked for the real tradeoffs between a plain string, a hard enum, and a proper `categories` table — including how platforms like Shopify or WooCommerce actually model this in production — before agreeing to scope down to a string column for time, with the FK design documented as the next step rather than silently dropped.
- On pagination, an early pass wasn't explicit about where filtering happened, so I asked for it to be pushed down to the database via `LIMIT`/`OFFSET` rather than fetched and filtered in the app.
- On the CSV importer, I questioned whether a bulk `insert_all` would outperform per-row inserts — which surfaced a real Postgres limitation (`ON CONFLICT DO UPDATE` can't target the same key twice in one statement), confirming per-row inserts were the correct choice for this file, not just the simpler one.
- On duplicate SKUs, I asked what would actually break if re-imports rejected repeats instead of upserting, before agreeing that idempotent re-import was the correct read of the sample data.
- On authentication, I caught the reasoning being framed as "no time for it" and asked whether it was actually a stated requirement. It wasn't — a more honest justification than a time cut, and the one that made it into the table.

Per the challenge's instructions, comments have been removed from the application code (`lib/`, including the generated Phoenix scaffold). Standard operational comments in `config/*.exs` (watcher setup, SSL notes, clustering) were left as-is — they're framework-standard reference notes for future maintainers, not explanatory comments about this app's logic.
