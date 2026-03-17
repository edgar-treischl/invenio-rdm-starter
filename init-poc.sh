#!/bin/bash
# Minimal POC setup for InvenioRDM v13 with admin-owned record
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

echo "=== Creating a single admin-owned record for file uploads ==="
docker compose exec -T web python3 - <<'PY'
from invenio_app.factory import create_api
from invenio_access.permissions import system_identity
from invenio_accounts.models import User
from invenio_rdm_records.proxies import current_rdm_records_service as service

app = create_api()
with app.app_context():
    admin = User.query.filter_by(email="admin@example.org").one_or_none()
    if not admin:
        raise Exception("Admin user not found")
    
    # Check if record exists
    search = service.search(system_identity, params={"q": 'metadata.title:"Admin POC Record"'})
    total = getattr(search, "total", 0)
    if isinstance(total, dict):
        total = total.get("value", 0)
    if total and total > 0:
        print("Admin-owned record already exists, skipping creation.")
    else:
        payload = {
            "metadata": {
                "title": "Admin POC Record",
                "description": "Single record owned by admin to enable file uploads",
                "resource_type": {"id": "dataset"},
                "creators": [
                    {
                        "name": "Admin User",
                        "person_or_org": "person",  # required for validation
                        "affiliations": [{"name": "My Organization"}]  # optional but recommended
                    }
                ],
                "publication_date": "2026-03-09",
            },
            "access": {"record": "public", "files": "public"},
            "files": {"enabled": True},
            "parent": {"access": {"owned_by": [{"user": str(admin.id)}]}}
        }
        draft = service.create(system_identity, payload)
        service.publish(system_identity, draft.id)
        print("Created and published admin-owned record ready for uploads.")
PY

echo "=== POC setup complete! ==="
echo "Admin: admin@example.org / admin123"
echo "Researcher: researcher@example.org / research123"
echo "Visit: https://localhost (accept the self-signed certificate)."
echo "You can now upload files to the 'Admin POC Record' as admin via the UI."