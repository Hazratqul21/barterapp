#!/usr/bin/env bash
# Tested release deployment with a pre-migration backup and code rollback.
set -euo pipefail
umask 077
APP=/opt/mab
DO_API=${DO_API:-1}
DO_WEB=${DO_WEB:-1}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP=/var/backups/mab/releases/$STAMP
mkdir -p "$BACKUP"
exec 9>/run/lock/mab-deploy.lock
flock -n 9 || { echo 'Another deployment is running.'; exit 1; }
if [ "$DO_API" = 1 ]; then
  sudo -u postgres pg_dump -Fc mab > "$BACKUP/database.dump"
  pg_restore --list "$BACKUP/database.dump" >/dev/null
  mkdir "$BACKUP/api"
  rsync -a --exclude .venv --exclude media "$APP/api/" "$BACKUP/api/"
  # Dependencies are installed before replacing the working code.
  sudo -u mab "$APP/api/.venv/bin/pip" install -q -r /tmp/mab-api/requirements.txt
  rsync -a --delete --exclude .venv --exclude .env --exclude media /tmp/mab-api/ "$APP/api/"
  chown -R mab:mab "$APP/api"
  if ! sudo -u mab bash -c "cd $APP/api && .venv/bin/alembic upgrade head"; then
    rsync -a --delete --exclude .venv --exclude media "$BACKUP/api/" "$APP/api/"
    echo 'Migration failed. Previous code restored; database backup retained.'; exit 1
  fi
  systemctl restart mab-api
  healthy=0
  for _ in $(seq 1 30); do
    if curl -fs --max-time 3 http://127.0.0.1:8010/health >/dev/null; then healthy=1; break; fi
    sleep 1
  done
  if [ "$healthy" != 1 ]; then
    rsync -a --delete --exclude .venv --exclude media "$BACKUP/api/" "$APP/api/"
    systemctl restart mab-api
    echo 'Health check failed. Previous code restored; additive DB migrations retained.'; exit 1
  fi
  systemctl start mab-push.timer mab-maintenance.timer
  echo 'API health verified.'
fi
if [ "$DO_WEB" = 1 ]; then
  release=/var/www/mab-releases/$STAMP
  mkdir -p "$release"
  rsync -a /tmp/mab-web/ "$release/"
  if [ -d /var/www/mab/.well-known ]; then cp -a /var/www/mab/.well-known "$release/"; fi
  test -s "$release/index.html"
  chown -R root:www-data "$release"
  find "$release" -type d -exec chmod 755 {} +
  find "$release" -type f -exec chmod 644 {} +
  if [ -L /var/www/mab ]; then
    readlink /var/www/mab > "$BACKUP/previous-web-path"
  elif [ -d /var/www/mab ]; then
    mv /var/www/mab "$BACKUP/web"
    echo "$BACKUP/web" > "$BACKUP/previous-web-path"
  fi
  ln -s "$release" /var/www/mab-next
  mv -Tf /var/www/mab-next /var/www/mab
  echo 'Web release activated.'
fi
printf 'Rollback backup: %s\n' "$BACKUP"
