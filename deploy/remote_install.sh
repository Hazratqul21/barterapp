#!/usr/bin/env bash
# deploy.sh serverda shu skriptni sudo bilan ishga tushiradi.
set -euo pipefail
APP=/opt/mab
DO_API=${DO_API:-1}
DO_WEB=${DO_WEB:-1}

if [ "$DO_API" = 1 ]; then
  rsync -a --delete --exclude '.venv' --exclude '.env' /tmp/mab-api/ "$APP/api/"
  chown -R mab:mab "$APP/api"
  PY=$(cat "$APP/.python" 2>/dev/null || echo python3)
  sudo -u mab bash -c "cd $APP/api && { [ -d .venv ] || $PY -m venv .venv; } \
    && .venv/bin/pip install -q --upgrade pip && .venv/bin/pip install -q -r requirements.txt \
    && .venv/bin/alembic upgrade head"
  systemctl restart mab-api
  systemctl start mab-push.timer mab-maintenance.timer
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

# Huquqiy hujjatlar manzillari (mab.uz/privacy …) → API. Server avvalroq
# o'rnatilgan bo'lsa, nginx sozlamasida bu qator hali yo'q — qo'shib qo'yamiz.
if [ -f /tmp/mab-legal.conf ]; then
  install -D -m 644 /tmp/mab-legal.conf /etc/nginx/snippets/mab-legal.conf
  CONF=/etc/nginx/sites-available/mab.conf
  if [ -f "$CONF" ] && ! grep -q "mab-legal.conf" "$CONF"; then
    cp "$CONF" "$CONF.bak"
    sed -i 's|^\(\s*\)root /var/www/mab;|&\n\1include snippets/mab-legal.conf;|' "$CONF"
  fi
  if nginx -t 2>/dev/null; then
    systemctl reload nginx
  elif [ -f "$CONF.bak" ]; then
    echo "nginx sozlamasi xato bo'ldi — eski holatiga qaytarildi."
    cp "$CONF.bak" "$CONF" && systemctl reload nginx
  fi
fi

if [ "$DO_WEB" = 1 ]; then
  rsync -a --delete --exclude '.well-known' /tmp/mab-web/ /var/www/mab/
  chown -R www-data:www-data /var/www/mab
  echo "Sayt yangilandi."
fi
