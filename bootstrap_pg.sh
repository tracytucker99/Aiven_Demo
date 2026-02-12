#!/usr/bin/env bash
set -euo pipefail

echo "==> Step 1: Install Postgres CA as ~/.postgresql/root.crt"
mkdir -p "$HOME/.postgresql"

# Pick the CA file from Downloads (your file is ca(1).pem)
CA_SRC="$HOME/Downloads/ca(1).pem"
if [ ! -f "$CA_SRC" ]; then
  echo "ERROR: Can't find $CA_SRC"
  echo "Run: ls -lah ~/Downloads | egrep -i 'ca|cert|crt|pem|aiven'"
  exit 1
fi

cp -f "$CA_SRC" "$HOME/.postgresql/root.crt"
chmod 0600 "$HOME/.postgresql/root.crt"
ls -lah "$HOME/.postgresql/root.crt"
echo

echo "==> Step 2: Build a fresh PG_DSN into .env"
read -r -p "PG host [demo-pg-avien-project.g.aivencloud.com]: " PG_HOST
PG_HOST="${PG_HOST:-demo-pg-avien-project.g.aivencloud.com}"

read -r -p "PG port [21767]: " PG_PORT
PG_PORT="${PG_PORT:-21767}"

read -r -p "PG db   [defaultdb]: " PG_DB
PG_DB="${PG_DB:-defaultdb}"

read -r -p "PG user [avnadmin]: " PG_USER
PG_USER="${PG_USER:-avnadmin}"

read -r -s -p "PG password (AVNS_oP8RtwoHXn23f8qOqxT): " PG_PASS
echo

# URL-encode password safely (handles special chars)
PG_PASS_ENC="$(python3 -c 'import os,urllib.parse; print(urllib.parse.quote(os.environ["PG_PASS"], safe=""))' PG_PASS="$PG_PASS")"

cat > .env <<EOF
PG_DSN="postgres://${PG_USER}:${PG_PASS_ENC}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=verify-full"
PG_CA_CERT_PATH="\$HOME/.postgresql/root.crt"
EOF

echo "Wrote .env with PG_DSN (password hidden)."
echo

echo "==> Step 3: DSN sanity + psql connectivity test"
set -a
source .env
set +a

python3 -c 'import os,urllib.parse; u=urllib.parse.urlparse(os.environ["PG_DSN"]); print("scheme:",u.scheme); print("user:",u.username); print("host:",u.hostname); print("port:",u.port); print("db:",u.path.lstrip("/")); print("query:",u.query)'

echo
echo "Trying psql..."
psql "$PG_DSN" -c "select now(), current_database(), current_user, inet_server_port();"

echo
echo "✅ SUCCESS: Postgres is reachable from this laptop with this PG_DSN."
