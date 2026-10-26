#!/usr/bin/env bash
# deploy.sh serverda shu skriptni sudo bilan ishga tushiradi.
#   STAGE — deploy.sh yaratgan vaqtinchalik papka (mktemp -d, faqat egasiga ochiq)
#
# Tartib: zaxira → kutubxonalar → kod → migratsiya → health-check. Migratsiya
# yoki health-check yiqilsa, oldingi kod qaytariladi (baza nusxasi qoladi).
# Sayt har safar yangi release papkasiga yoziladi va symlink bilan almashadi.
set -euo pipefail
APP=/opt/mab
DO_API=${DO_API:-1}
DO_WEB=${DO_WEB:-1}
STAGE=${STAGE:?STAGE berilmadi}
# Faqat deploy.sh yaratgan papka: boshqa joydan fayl o'rnatilmasin.
case "$STAGE" in /tmp/mab-deploy.*) ;; *) echo "STAGE noto'g'ri: $STAGE"; exit 1 ;; esac
[ "$(stat -c %u "$STAGE")" = "${SUDO_UID:-0}" ] || { echo "STAGE egasi noto'g'ri"; exit 1; }
trap 'rm -rf "$STAGE"' EXIT

exec 9>/run/lock/mab-deploy.lock
flock -n 9 || { echo "Boshqa deploy ishlayapti."; exit 1; }

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP=/var/backups/mab/releases/$STAMP
install -d -m 700 /var/backups/mab /var/backups/mab/releases "$BACKUP"

# --- Xizmatlar va kunlik zaxira ---------------------------------------------
install -m 700 "$STAGE/backup.sh" /usr/local/sbin/mab-backup
for unit in mab-api.service mab-push.service mab-push.timer mab-maintenance.service \
            mab-maintenance.timer mab-backup.service mab-backup.timer; do
  install -m 644 "$STAGE/systemd/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now mab-backup.timer >/dev/null
install -d -o mab -g mab -m 750 "$APP/media"

restore_code() {
  rsync -a --delete --exclude .venv --exclude '.env*' --exclude media "$BACKUP/api/" "$APP/api/"
  chown -R mab:mab "$APP/api"
}

if [ "$DO_API" = 1 ]; then
  ( umask 077
    sudo -u postgres pg_dump -Fc mab > "$BACKUP/database.dump" )
  pg_restore --list "$BACKUP/database.dump" >/dev/null
  mkdir -p "$BACKUP/api"
  rsync -a --exclude .venv --exclude media "$APP/api/" "$BACKUP/api/"

  chown -R mab:mab "$STAGE/api"
  # STAGE 700 (mktemp -d): mab ichidagi api/ ga yetib bora olsin. 711 —
  # faqat o'tish huquqi: papka ro'yxatini boshqalar ko'ra olmaydi.
  chmod 711 "$STAGE"
  PY=$(cat "$APP/.python" 2>/dev/null || echo python3)
  [ -d "$APP/api/.venv" ] || sudo -u mab "$PY" -m venv "$APP/api/.venv"
  # Kutubxonalar kod almashishidan OLDIN: o'rnatish yiqilsa, eski kod ishlab turadi.
  sudo -u mab "$APP/api/.venv/bin/pip" install -q --upgrade pip
  sudo -u mab "$APP/api/.venv/bin/pip" install -q -r "$STAGE/api/requirements.txt"

  rsync -a --delete --exclude .venv --exclude '.env*' --exclude media "$STAGE/api/" "$APP/api/"
  chown -R mab:mab "$APP/api"
  if ! sudo -u mab bash -c "cd $APP/api && .venv/bin/alembic upgrade head"; then
    restore_code
    echo "Migratsiya yiqildi. Oldingi kod qaytarildi; baza nusxasi: $BACKUP/database.dump"
    exit 1
  fi

  systemctl restart mab-api
  healthy=0
  for _ in $(seq 1 30); do
    if curl -fs --max-time 3 http://127.0.0.1:8010/health >/dev/null; then healthy=1; break; fi
    sleep 1
  done
  if [ "$healthy" != 1 ]; then
    echo "API ishga tushmadi. Sabab:"
    journalctl -u mab-api -n 30 --no-pager || true
    restore_code
    systemctl restart mab-api
    echo "Oldingi kod qaytarildi (migratsiyalar faqat qo'shuvchi, bazada qoladi)."
    exit 1
  fi
  systemctl enable --now mab-push.timer mab-maintenance.timer >/dev/null
  echo "API ishlayapti."
fi

# --- nginx ------------------------------------------------------------------
# Hujjat manzillari (mab.uz/privacy …) → API, saytning xavfsizlik
# sarlavhalari, noma'lum domenlarni rad etish. certbot yozgan faylga faqat
# yetishmayotgan `include` qatorlari qo'shiladi; xato bo'lsa — qaytariladi.
install -D -m 644 "$STAGE/nginx/mab-legal.conf" /etc/nginx/snippets/mab-legal.conf
install -D -m 644 "$STAGE/nginx/mab-web-headers.conf" /etc/nginx/snippets/mab-web-headers.conf
install -D -m 644 "$STAGE/nginx/mab-gzip.conf" /etc/nginx/snippets/mab-gzip.conf
install -D -m 644 "$STAGE/nginx/mab-http.conf" /etc/nginx/conf.d/mab-http.conf
# harden_server.sh ning eski sarlavha fayli: endi mab-web-headers.conf (sayt)
# va API'ning o'zi (main.py) beradi. Ikki marta yuborilmasin.
[ -f /etc/nginx/snippets/mab-security-headers.conf ] && \
  echo "# Sarlavhalar endi mab-web-headers.conf va API'da." > /etc/nginx/snippets/mab-security-headers.conf
CONF=/etc/nginx/sites-available/mab.conf
if [ -f "$CONF" ]; then
  cp "$CONF" "$BACKUP/nginx-mab.conf"
  # `root /var/www/mab;` certbot/qo'lda `root /var/www/mab/ ;` bo'lib ham qolishi mumkin.
  ROOT_RE='^\(\s*\)root\s\+/var/www/mab/\?\s*;'
  grep -q "mab-legal.conf" "$CONF" \
    || sed -i "s|$ROOT_RE|&\n\1include snippets/mab-legal.conf;|" "$CONF"
  grep -q "mab-legal.conf" "$CONF" || {
    echo "DIQQAT: $CONF da 'root /var/www/mab;' topilmadi — mab.uz/privacy, /offer"
    echo "ochilmaydi. Sayt bloki ichiga qo'lda qo'shing: include snippets/mab-legal.conf;"
  }
  grep -q "mab-web-headers.conf" "$CONF" || {
    sed -i "s|$ROOT_RE|&\n\1include snippets/mab-web-headers.conf;|" "$CONF"
    sed -i 's|^\(\s*\)add_header Cache-Control "no-cache";|&\n\1include snippets/mab-web-headers.conf;|' "$CONF"
  }
  # Siqish: sayt (root qatori) va API (client_max_body_size qatori) bloklariga.
  grep -q "mab-gzip.conf" "$CONF" || {
    sed -i "s|$ROOT_RE|&\n\1include snippets/mab-gzip.conf;|" "$CONF"
    sed -i 's|^\(\s*\)client_max_body_size 16m;|&\n\1include snippets/mab-gzip.conf;|' "$CONF"
  }
  # .well-known fayllari .json qoidasiga tushib qolmasin.
  sed -i 's|^\(\s*\)location /.well-known/ {|\1location ^~ /.well-known/ {|' "$CONF"
fi
if nginx -t 2>/dev/null; then
  systemctl reload nginx
else
  echo "nginx sozlamasi xato bo'ldi — eski holatiga qaytarildi:"
  nginx -t 2>&1 | tail -3 || true
  [ -f "$BACKUP/nginx-mab.conf" ] && cp "$BACKUP/nginx-mab.conf" "$CONF"
  rm -f /etc/nginx/conf.d/mab-http.conf
  nginx -t 2>/dev/null && systemctl reload nginx
fi

# --- Sayt -------------------------------------------------------------------
if [ "$DO_WEB" = 1 ]; then
  test -s "$STAGE/web/index.html" || { echo "Sayt build'ida index.html yo'q."; exit 1; }
  # Papkalar nginx (www-data) o'qiy oladigan bo'lsin — 700 bo'lib qolgan
  # releases papkasi saytni 500 bilan to'xtatgan edi.
  install -d -m 755 /var/www/mab-releases
  release=/var/www/mab-releases/$STAMP
  install -d -m 755 "$release"
  rsync -a "$STAGE/web/" "$release/"
  if [ -d /var/www/mab/.well-known ]; then cp -a /var/www/mab/.well-known "$release/"; fi
  chown -R root:www-data "$release"
  find "$release" -type d -exec chmod 755 {} +
  find "$release" -type f -exec chmod 644 {} +
  if [ -L /var/www/mab ]; then
    readlink /var/www/mab > "$BACKUP/previous-web-path"
  elif [ -d /var/www/mab ]; then
    mv /var/www/mab "$BACKUP/web"
    echo "$BACKUP/web" > "$BACKUP/previous-web-path"
  fi
  ln -sfn "$release" /var/www/mab-next
  mv -Tf /var/www/mab-next /var/www/mab
  # Eskilari: oxirgi 5 ta release qoladi.
  ls -1dt /var/www/mab-releases/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf --
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: mab.uz" -k https://127.0.0.1/ || true)
  [ "$code" = 200 ] || code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: mab.uz" http://127.0.0.1/ || true)
  echo "Sayt yangilandi (tekshiruv: $code)."
fi
printf 'Orqaga qaytarish nusxasi: %s\n' "$BACKUP"
