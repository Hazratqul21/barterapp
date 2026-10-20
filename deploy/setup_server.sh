#!/usr/bin/env bash
# MAB serverini bir marta tayyorlash (Ubuntu 22.04 / 24.04).
#
#   sudo EMAIL=siz@mab.uz bash setup_server.sh
#
# Qayta ishga tushirish xavfsiz: bor narsa (baza, .env, kalitlar) qayta
# yaratilmaydi. Odatda bu skriptni deploy/deploy.sh --setup o'zi chaqiradi.
set -euo pipefail

DOMAIN=${DOMAIN:-mab.uz}
API_DOMAIN=${API_DOMAIN:-api.mab.uz}
EMAIL=${EMAIL:-}
APP_USER=mab
APP_DIR=/opt/mab
WEB_DIR=/var/www/mab
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring."; exit 1; }

step "Paketlar"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q postgresql nginx certbot python3-certbot-nginx rsync ufw curl \
  software-properties-common python3 python3-venv

# Server Python 3.11+ talab qiladi. Ubuntu 22.04 da 3.10 — 3.12 qo'shiladi.
PY=python3
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  add-apt-repository -y ppa:deadsnakes/ppa
  apt-get update -q
  apt-get install -y -q python3.12 python3.12-venv
  PY=python3.12
fi
echo "Python: $($PY --version)"

step "Foydalanuvchi va papkalar"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home \
  --home-dir "$APP_DIR" --shell /bin/bash "$APP_USER"
mkdir -p "$APP_DIR/api" "$APP_DIR/media" "$WEB_DIR"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
echo "$PY" > "$APP_DIR/.python"

step "PostgreSQL"
DB_PASS_FILE="$APP_DIR/.db_password"
if [ ! -f "$DB_PASS_FILE" ]; then
  openssl rand -hex 24 > "$DB_PASS_FILE"
  chmod 600 "$DB_PASS_FILE"; chown "$APP_USER:$APP_USER" "$DB_PASS_FILE"
fi
DB_PASS=$(cat "$DB_PASS_FILE")
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='mab'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE mab LOGIN PASSWORD '$DB_PASS'"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='mab'" | grep -q 1 \
  || sudo -u postgres createdb -O mab mab

step "Server sozlamasi (.env)"
ENV_FILE="$APP_DIR/api/.env"
if [ ! -f "$ENV_FILE" ]; then
  JWT=$(openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-64)
  cat > "$ENV_FILE" <<EOF
# MAB — production. Bu fayl faqat serverda turadi, git'ga tushmaydi.
APP_ENV=production
DATABASE_URL=postgresql+asyncpg://mab:$DB_PASS@127.0.0.1:5432/mab
JWT_SECRET=$JWT
OTP_DEBUG=false
CORS_ORIGINS=["https://$DOMAIN","https://www.$DOMAIN"]
MEDIA_ROOT=$APP_DIR/media

# SMS (Eskiz) — to'ldirilmaguncha production rejimi server ishga tushishiga
# yo'l qo'ymaydi: SMS bo'lmasa hech kim kira olmaydi.
SMS_REQUIRED=true
# Eskiz kelguncha vaqtincha: SMS_OPTIONAL=true (kodlar: journalctl -u mab-api)
ESKIZ_EMAIL=
ESKIZ_PASSWORD=
# ESKIZ_SENDER=4546
# ESKIZ_OTP_TEMPLATE=MAB: tasdiqlash kodi {code}. Hech kimga aytmang.

# Payme — shartnomadan keyin.
# PAYME_MERCHANT_ID=
# PAYME_KEY=
# PAYME_CHECKOUT_URL=https://test.paycom.uz
EOF
  chmod 600 "$ENV_FILE"; chown "$APP_USER:$APP_USER" "$ENV_FILE"
  echo "Yaratildi: $ENV_FILE  (Eskiz ma'lumotlarini kiriting)"
else
  echo "Bor: $ENV_FILE — tegilmadi."
fi

step "systemd: API va fon vazifalari"
install -m 644 "$HERE/systemd/mab-api.service" /etc/systemd/system/mab-api.service
for unit in mab-push mab-maintenance; do
  install -m 644 "$HERE/systemd/$unit.service" "/etc/systemd/system/$unit.service"
  install -m 644 "$HERE/systemd/$unit.timer" "/etc/systemd/system/$unit.timer"
done
systemctl daemon-reload
systemctl enable mab-api.service mab-push.timer mab-maintenance.timer >/dev/null

step "nginx"
install -D -m 644 "$HERE/nginx/mab-legal.conf" /etc/nginx/snippets/mab-legal.conf
NGINX_CONF=/etc/nginx/sites-available/mab.conf
# certbot HTTPS'ni shu faylga yozadi. Qayta ishga tushirishda uni ustidan
# yozsak, sertifikat sozlamasi yo'qoladi va sayt https'da ochilmay qoladi.
if [ -f "$NGINX_CONF" ] && grep -q "managed by Certbot" "$NGINX_CONF"; then
  echo "Bor: $NGINX_CONF (certbot sozlagan) — tegilmadi."
else
  sed -e "s/__DOMAIN__/$DOMAIN/g" -e "s/__API_DOMAIN__/$API_DOMAIN/g" \
    "$HERE/nginx/mab.conf" > "$NGINX_CONF"
fi
ln -sf /etc/nginx/sites-available/mab.conf /etc/nginx/sites-enabled/mab.conf
rm -f /etc/nginx/sites-enabled/default
[ -f "$WEB_DIR/index.html" ] || echo '<!doctype html><title>MAB</title><p>MAB tez orada.</p>' > "$WEB_DIR/index.html"
nginx -t && systemctl reload nginx

step "Firewall"
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null
ufw status | head -5

step "HTTPS sertifikat (Let's Encrypt)"
if [ -z "$EMAIL" ]; then
  echo "EMAIL berilmadi — sertifikat keyinroq:"
  echo "  sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN -d $API_DOMAIN --redirect -m <email> --agree-tos -n"
elif certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" -d "$API_DOMAIN" \
     --redirect -m "$EMAIL" --agree-tos -n; then
  echo "Sertifikat o'rnatildi, avtomatik yangilanadi."
else
  echo "Sertifikat olinmadi: DNS hali bu serverga ko'rsatmayotgan bo'lishi mumkin."
  echo "DNS tayyor bo'lgach: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN -d $API_DOMAIN --redirect -m $EMAIL --agree-tos -n"
fi

echo
echo "Server tayyor. Kod: deploy/deploy.sh (noutbukdan)."
