#!/bin/bash
# Fully automated POC setup for InvenioRDM starter v13 (idempotent, no shell inside containers)
set -euo pipefail

echo "=== Resetting Docker Compose stack ==="
docker compose down -v || true

echo "=== Starting Docker Compose stack ==="
docker compose up -d

WEB=$(docker compose ps -q web)
WORKER=$(docker compose ps -q worker)

wait_ready() {
  local cid="$1"
  local name="$2"
  echo "Waiting for ${name} to be ready..."
  for _ in {1..60}; do
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo "starting")
    if [[ "$health" == "healthy" || "$health" == "running" ]]; then
      echo "${name} is ready (${health})."
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for ${name} to be ready."
  exit 1
}

wait_ready "$WEB" "web"
wait_ready "$WORKER" "worker"

echo "=== Initializing DB and search indices ==="
docker compose exec -T web invenio db create
docker compose exec -T web invenio db init
docker compose exec -T web invenio index destroy --force --yes-i-know || true
docker compose exec -T web invenio index init
docker compose exec -T web invenio files location create --default default file:///opt/invenio/var/instance/data || true
docker compose exec -T web invenio rdm-records fixtures
docker compose exec -T web invenio rdm rebuild-all-indices

echo "=== Creating users ==="
docker compose exec -T web invenio roles create admin || true
docker compose exec -T web invenio users create admin@example.org --password admin123 --active --confirm || true
docker compose exec -T web invenio roles add admin@example.org admin || true
docker compose exec -T web invenio users create researcher@example.org --password research123 --active --confirm || true

echo "=== Seeding demo records ==="
docker compose exec -T web python3 - <<'PY'
from invenio_app.factory import create_api
from invenio_access.permissions import system_identity
from invenio_rdm_records.proxies import current_rdm_records_service as service

records = [
    {
        "title": "Iris Flower Dataset",
        "description": "Classic Iris flower dataset used for ML classification.",
        "publication_date": "1936-01-01",
        "creators": [
            {"person_or_org": {"family_name": "Fisher", "given_name": "Ronald", "type": "personal"}}
        ],
        "resource_type": {"id": "dataset"},
    },
    {
        "title": "Palmer Penguins Dataset",
        "description": "Penguins dataset for statistical examples.",
        "publication_date": "2020-01-01",
        "creators": [
            {"person_or_org": {"family_name": "Horst", "given_name": "Allison", "type": "personal"}}
        ],
        "resource_type": {"id": "dataset"},
    },
]


def ensure_record(title, data):
    search = service.search(system_identity, params={"q": f'metadata.title:"{title}"'})
    total = getattr(search, "total", 0)
    if isinstance(total, dict):
        total = total.get("value", 0)
    if total and total > 0:
        print(f"Record already exists: {title}")
        return
    payload = {
        "metadata": {
            "title": data["title"],
            "description": data["description"],
            "publication_date": data["publication_date"],
            "creators": data["creators"],
            "resource_type": data["resource_type"],
        },
        "access": {"record": "public", "files": "public"},
        "files": {"enabled": True},
    }
    draft = service.create(system_identity, payload)
    service.publish(system_identity, draft.id)
    print(f"Created record: {title}")


app = create_api()
with app.app_context():
    for rec in records:
        ensure_record(rec["title"], rec)
PY

echo "=== POC setup complete! ==="
echo "Admin: admin@example.org / admin123"
echo "Researcher: researcher@example.org / research123"
echo "Visit: https://localhost (accept the self-signed certificate)."
