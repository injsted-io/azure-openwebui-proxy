#!/bin/bash
set -euxo pipefail
# mirror user-data output to local file + EC2 serial console (so "Get system log" shows progress)
exec > >(tee -a /var/log/user-data-exec.log | logger -t user-data -s 2>/dev/console) 2>&1

REGION="${region}"
PREFIX="${ssm_prefix}"

# small retry helper
retry() { local n=0 max=6 delay=5; until "$@"; do n=$((n+1)); [ $n -ge $max ] && { echo "FAIL: $*"; return 1; }; sleep $delay; done; }

# basic egress preflight (DNS/route ready)
retry curl -fsSL https://checkip.amazonaws.com >/dev/null

# ---------- System prep ----------
dnf update -y
dnf install -y amazon-ssm-agent git
systemctl enable --now amazon-ssm-agent

# Docker engine (AL2023)
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user || true

# Auto-grant docker group to ssm-user when it appears (nice DX for SSM sessions)
cat >/etc/systemd/system/grant-docker-ssm-user.service <<'UNIT'
[Unit]
Description=Grant docker group to ssm-user
[Service]
Type=oneshot
ExecStart=/usr/sbin/usermod -aG docker ssm-user
UNIT

cat >/etc/systemd/system/grant-docker-ssm-user.path <<'UNIT'
[Unit]
Description=Watch for ssm-user home to grant docker group
[Path]
PathExists=/home/ssm-user
[Install]
WantedBy=multi-user.target
UNIT

systemctl enable --now grant-docker-ssm-user.path

# ---------- Docker Compose v2 CLI plugin ----------
mkdir -p /usr/local/lib/docker/cli-plugins
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then
  COMPOSE_URL="https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64"
else
  COMPOSE_URL="https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-aarch64"
fi
curl -fsSL "$COMPOSE_URL" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version

mkdir -p /opt/openwebui
cd /opt/openwebui

# ---------- SSM helper ----------
getp() {
  aws ssm get-parameter --region "$REGION" --name "$1" --with-decryption \
    --query 'Parameter.Value' --output text
}

# ---------- Build .env (no Azure vars) ----------
: > .env
missing=0
for KEY in ENV STORAGE_PROVIDER DATABASE_URL S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_REGION_NAME S3_BUCKET_NAME S3_ENDPOINT_URL; do
  NAME="$PREFIX/$KEY"
  if VAL="$(getp "$NAME" 2>/dev/null)"; then
    printf '%s=%s\n' "$KEY" "$VAL" >> .env
  else
    echo "MISSING SSM PARAM: $NAME"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "One or more required parameters missing in SSM; aborting."
  exit 1
fi

# (optional) if you store a fixed WEBUI_SECRET_KEY in SSM, add it:
# if VAL="$(getp "$PREFIX/WEBUI_SECRET_KEY" 2>/dev/null)"; then
#   printf '%s=%s\n' "WEBUI_SECRET_KEY" "$VAL" >> .env
# fi

# quick sanity (non-secret)
grep -E '^(ENV|STORAGE_PROVIDER|S3_BUCKET_NAME|S3_REGION_NAME)=' .env || true

# ---------- Wait for Postgres (best-effort) ----------
DBURL="$(sed -n 's/^DATABASE_URL=//p' .env)"
DB_HOST="$(echo "$DBURL" | sed -E 's#^[^@]+@([^:/]+):([0-9]+).*$#\1#')"
DB_PORT="$(echo "$DBURL" | sed -E 's#^[^@]+@([^:/]+):([0-9]+).*$#\2#')"
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
  echo "Waiting for Postgres at $DB_HOST:$DB_PORT..."
  retry bash -lc "timeout 2 bash -lc 'cat </dev/null >/dev/tcp/$DB_HOST/$DB_PORT'"
fi

# ---------- Compose file ----------
cat > docker-compose.yml <<'YAML'
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:latest
    pull_policy: always
    ports:
      - "3020:8080"
    env_file:
      - .env
    volumes:
      - open-webui-data:/app/backend/data
    restart: always
volumes:
  open-webui-data:
YAML

# ---------- Start ----------
retry docker compose pull
docker compose up -d
docker compose ps
