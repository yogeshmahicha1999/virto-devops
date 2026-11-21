#!/usr/bin/env bash
# One-command setup: start everything and install Virto modules (admin UI etc.)
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { sed "s/CHANGE_ME/$(openssl rand -hex 16)/" .env.example > .env; echo ".env created"; }
set -a; . ./.env; set +a
ADMIN_PASSWORD="${ADMIN_PASSWORD:-store}"   # Virto default for a fresh database
DC="docker compose --env-file .env -f docker/docker-compose.yml"
MODS='ls /opt/virtocommerce/platform/modules | wc -l'

wait_healthy() {
  for i in $(seq 1 60); do
    s=$(docker inspect -f '{{.State.Health.Status}}' "$($DC ps -q platform)" 2>/dev/null || true)
    [ "$s" = "healthy" ] && return 0; sleep 10
  done; echo "platform not healthy"; exit 1
}

echo "1/4 Starting containers (first build takes a few minutes)..."
$DC up -d --build
echo "2/4 Waiting for backend to be healthy..."
wait_healthy

echo "3/4 Installing Virto modules (this version does not auto-install them)..."
if [ "$($DC exec -T platform bash -c "$MODS" | tr -d '[:space:]')" -lt 5 ]; then
  TOKEN=$(curl -s -X POST "http://localhost:$PLATFORM_PORT/connect/token" \
    --data-urlencode grant_type=password --data-urlencode username=admin \
    --data-urlencode "password=$ADMIN_PASSWORD" | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
  curl -s -o /dev/null -X POST "http://localhost:$PLATFORM_PORT/api/platform/modules/autoinstall" -H "Authorization: Bearer $TOKEN"
  prev=-1
  for i in $(seq 1 40); do
    n=$($DC exec -T platform bash -c "$MODS" | tr -d '[:space:]')
    [ "$n" -ge 30 ] && [ "$n" = "$prev" ] && break
    prev=$n; sleep 10
  done
  $DC restart platform
  wait_healthy
fi

echo "4/4 Waiting for admin UI..."
for i in $(seq 1 60); do
  curl -s "http://localhost:$PLATFORM_PORT/" | grep -q "No admin UI" || break; sleep 10
done

echo
echo "DONE"
echo "  Backend admin : http://localhost:$PLATFORM_PORT   (user: admin)"
echo "  Frontend site : http://localhost:$FRONTEND_PORT"
