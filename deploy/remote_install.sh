#!/usr/bin/env bash
# deploy.sh serverda shu skriptni sudo bilan ishga tushiradi.
#   STAGE  — deploy.sh yaratgan vaqtinchalik papka (mktemp -d)
set -euo pipefail
APP=/opt/mab
DO_API=${DO_API:-1}
DO_WEB=${DO_WEB:-1}
STAGE=${STAGE:?STAGE berilmadi}
# Faqat deploy.sh yaratgan papka: boshqa joydan fayl o'rnatilmasin.
case "$STAGE" in /tmp/mab-deploy.*) ;; *) echo "STAGE noto'g'ri: $STAGE"; exit 1 ;; esac
[ "$(stat -c %u "$STAGE")" = "${SUDO_UID:-0}" ] || { echo "STAGE egasi noto'g'ri"; exit 1; }
trap 'rm -rf "$STAGE"' EXIT

# --- Zaxira va xizmatlar ----------------------------------------------------
install -m 755 "$STAGE/backup.sh" /usr/local/sbin/mab-backup
for unit in mab-api.service mab-push.service mab-push.timer mab-maintenance.service \
            mab-maintenance.timer mab-backup.service mab-backup.timer; do
  install -m 644 "$STAGE/systemd/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now mab-backup.timer >/dev/null
install -d -o mab -g mab -m 750 "$APP/media"

if [ "$DO_API" = 1 ]; then
  # Migratsiya xato qilsa ham ma'lumot qaytariladigan bo'lsin.
  /usr/local/sbin/mab-backup pre-deploy
  rsync -a --delete --exclude '.venv' --exclude '.env*' --exclude 'media' \
    "$STAGE/api/" "$APP/api/"
  chown -R mab:mab "$APP/api"
  PY=$(cat "$APP/.python" 2>/dev/null || echo python3)
  sudo -u mab bash -c "cd $APP/api && { [ -d .venv ] || $PY -m venv .venv; } \
    && .venv/bin/pip install -q --upgrade pip && .venv/bin/pip install -q -r requirements.txt \
    && .venv/bin/alembic upgrade head"
  systemctl restart mab-api
  systemctl enable --now mab-push.timer mab-maintenance.timer >/dev/null
  for _ in $(seq 1 20); do
    curl -fs http://127.0.0.1:8010/health >/dev/null && break
    sleep 1
  done
  if curl -fs http://127.0.0.1:8010/health >/dev/null; then
    echo "API ishlayapti."
  else
    echo "API ishga tushmadi. Sabab:"
    journalctl -u mab-api -n 30 --no-pager
    exit 1
  fi
fi

# --- nginx ------------------------------------------------------------------
# Hujjat manzillari (mab.uz/privacy …) → API, saytning xavfsizlik
# sarlavhalari va noma'lum domenlarni rad etish. certbot yozgan faylga
# faqat yetishmayotgan `include` qatorlari qo'shiladi; xato bo'lsa — qaytariladi.
install -D -m 644 "$STAGE/nginx/mab-legal.conf" /etc/nginx/snippets/mab-legal.conf
install -D -m 644 "$STAGE/nginx/mab-web-headers.conf" /etc/nginx/snippets/mab-web-headers.conf
install -D -m 644 "$STAGE/nginx/mab-http.conf" /etc/nginx/conf.d/mab-http.conf
CONF=/etc/nginx/sites-available/mab.conf
if [ -f "$CONF" ]; then
  cp "$CONF" "$CONF.bak"
  grep -q "mab-legal.conf" "$CONF" \
    || sed -i 's|^\(\s*\)root /var/www/mab;|&\n\1include snippets/mab-legal.conf;|' "$CONF"
  grep -q "mab-web-headers.conf" "$CONF" || {
    sed -i 's|^\(\s*\)root /var/www/mab;|&\n\1include snippets/mab-web-headers.conf;|' "$CONF"
    sed -i 's|^\(\s*\)add_header Cache-Control "no-cache";|&\n\1include snippets/mab-web-headers.conf;|' "$CONF"
  }
  # .well-known fayllari .json qoidasiga tushib qolmasin.
  sed -i 's|^\(\s*\)location /.well-known/ {|\1location ^~ /.well-known/ {|' "$CONF"
fi
if nginx -t 2>/dev/null; then
  systemctl reload nginx
else
  echo "nginx sozlamasi xato bo'ldi — eski holatiga qaytarildi:"
  nginx -t 2>&1 | tail -3 || true
  [ -f "$CONF.bak" ] && cp "$CONF.bak" "$CONF"
  rm -f /etc/nginx/conf.d/mab-http.conf
  nginx -t 2>/dev/null && systemctl reload nginx
fi

if [ "$DO_WEB" = 1 ]; then
  rsync -a --delete --exclude '.well-known' "$STAGE/web/" /var/www/mab/
  chown -R www-data:www-data /var/www/mab
  echo "Sayt yangilandi."
fi
