# InvenioRDM Starter – Copilot guide

## Build, test, and lint
- **Docker stack:** `docker compose up` (from repo root). On first run, initialize data with `docker exec -it invenio-rdm-starter-worker-1 setup.sh` (admin user `admin@inveniosoftware.org` / `changeme`).
- **Frontend assets (Node ≥18):** prefer `pnpm install && pnpm run build` in `assets/` (honors `pnpm-lock.yaml`); `pnpm run start` watches via webpack. Equivalent npm scripts exist in `package.json` if pnpm is unavailable.
- **Docs:** `uv run mkdocs build` (uses optional `docs` extra).
- **Tests/lint:** No automated test or lint commands are defined; runtime validation relies on the Invenio CLI (DB/index setup) executed by `entrypoint.py`/`setup.sh`.

## High-level architecture
- **Services (docker-compose):** Caddy reverse proxy (`proxy`), Gunicorn web app (`web`), Celery worker with beat (`worker`), Valkey/Redis cache+broker (`cache`), PostgreSQL (`db`), OpenSearch (`search`). Health checks gate startup; containers run read-only with tmpfs mounts and named volumes for data.
- **App runtime:** Image built via multi-stage `Dockerfile` (Python 3.13, Node 22, uv-managed venv). `entrypoint.py` initializes DB, indices, roles, admin user, fixtures, and custom fields, then execs the passed command (Gunicorn by default).
- **Instance payload:** `invenio.cfg` plus `site/`, `assets/`, `templates/`, `static/`, `app_data/`, and `translations/` copied into `/opt/invenio/var/instance/`. Frontend bundles use rspack/webpack (`WEBPACKEXT_PROJECT=invenio_assets.webpack:rspack_project`).
- **Data & fixtures:** Persistent volumes at `/opt/invenio/var/instance/data` and `/opt/invenio/var/instance/archive`; vocabularies and demo content live in `app_data/` and `demo_data/`. Translations configured via `translations/babel.ini`.

## Key conventions
- **Configuration:** Environment-driven (`.env` alongside `docker-compose.yml`) with `INVENIO_*` prefixes; defaults documented in `README.md` and `invenio.cfg`. Optional S3 storage (`INVENIO_S3_*`) and OIDC values are read at startup.
- **Dependencies:** Python managed with `uv` (`pyproject.toml` + `uv.lock`); frontend locked with `pnpm-lock.yaml`.
- **Custom fields & fixtures:** `entrypoint.py` ensures journal custom fields exist, initializes record/community custom fields, loads RDM fixtures, declares queues, and rebuilds indices when missing.
- **I18N:** Default locale `en`; supported languages configured via `INVENIO_ISO639_LANGUAGES` (defaults `fr,de,es,pt`); theme texts/logos configurable through `INVENIO_THEME_*`.
- **Security/runtime:** Containers run non-root with read-only FS and tmpfs for `/tmp` and `/var/run`; Caddy terminates TLS with self-signed cert for `https://localhost`.
