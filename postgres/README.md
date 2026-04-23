# PostgreSQL Learning Project

Same arc as `../sqlite/` (basics → advanced → prisma), but on PostgreSQL. The SQL is ~95% identical to what you wrote for SQLite; the extra mile is what SQLite *can't* teach: a real server, strict types, `JSONB`, `EXPLAIN ANALYZE`, and concurrent writers.

## Folders

- `basics/` — tables, joins, transactions. A Postgres-flavoured port of `sqlite/basics/` with notes where Postgres differs.
- `advanced/` — indexes + `EXPLAIN ANALYZE`, views (incl. materialized), CTEs, window functions. Plus Postgres-only: `JSONB`, arrays, full-text search.
- `prisma/` — same schema, same Prisma Client, one-line change in `schema.prisma` (`provider = "postgresql"`). Demonstrates how an ORM abstracts over the engine.

## Setup — you're here

Pick ONE of these. Once you're done, a `psql "<connection-string>"` prompt should open cleanly.

### Option A — Docker (recommended)

1. Turn on WSL integration in Docker Desktop: **Settings → Resources → WSL Integration → enable this distro → Apply**.
2. Start a container:
   ```bash
   docker run --name pg-learn \
     -e POSTGRES_PASSWORD=learn \
     -p 5432:5432 \
     -d postgres:17
   ```
3. Connect:
   ```bash
   docker exec -it pg-learn psql -U postgres
   ```

Useful container commands:
```bash
docker stop pg-learn      # pause
docker start pg-learn     # resume
docker rm -f pg-learn     # wipe completely (data gone)
```

### Option B — Native install (Ubuntu/WSL2)

```bash
sudo apt update
sudo apt install -y postgresql
sudo service postgresql start    # WSL has no systemd by default

# open a shell as the default postgres superuser
sudo -u postgres psql
```

Every time you reboot WSL: `sudo service postgresql start`.

### Option C — Cloud (Neon free tier)

1. Sign up at https://neon.tech → create a project.
2. Copy the connection string it gives you (looks like `postgresql://user:pass@ep-xxx.region.aws.neon.tech/dbname?sslmode=require`).
3. Install the client locally: `sudo apt install postgresql-client`.
4. `psql "<paste-connection-string>"`.

## Running lesson scripts

Same idea as SQLite. Once you have a running server:

```bash
# create the learning database (one-time)
createdb -h localhost -U postgres learn_pg

# run a script
psql -h localhost -U postgres -d learn_pg -f basics/02-basics.sql
```

(Replace host/user for cloud or Docker-with-different-creds.)

## Reset

- Docker: `docker rm -f pg-learn && docker run ...` (see Option A).
- Native: `dropdb learn_pg && createdb learn_pg`.
- Cloud: drop and recreate via the web console, or `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` from psql.
