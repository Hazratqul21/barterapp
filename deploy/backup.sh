#!/usr/bin/env bash
# MAB zaxira nusxasi: baza (pg_dump -Fc) va /opt/mab/media.
#
#   sudo mab-backup              # qo'lda
#   sudo mab-backup pre-deploy   # deploydan oldin (remote_install.sh chaqiradi)
#
# Natija /var/backups/mab da, 14 kun saqlanadi. Server buzilsa ham nusxa
# qolishi uchun bu papkani vaqti-vaqti bilan boshqa joyga ko'chiring
# (deploy/README.md → "Zaxira nusxa").
#
# Tiklash:
#   sudo -u postgres pg_restore --clean --if-exists -d mab /var/backups/mab/mab-<...>.dump
#   sudo tar -xzf /var/backups/mab/media-<...>.tar.gz -C /opt/mab
set -euo pipefail
DIR=/var/backups/mab
TAG=${1:-daily}
STAMP=$(date +%F-%H%M)
install -d -m 700 -o root -g root "$DIR"
umask 077
sudo -u postgres pg_dump -Fc mab > "$DIR/mab-$TAG-$STAMP.dump"
if [ "$TAG" = daily ] && [ -d /opt/mab/media ]; then
  tar -czf "$DIR/media-$STAMP.tar.gz" -C /opt/mab media
fi
find "$DIR" -type f \( -name '*.dump' -o -name '*.tar.gz' \) -mtime +14 -delete
echo "Zaxira: $DIR/mab-$TAG-$STAMP.dump ($(du -h "$DIR/mab-$TAG-$STAMP.dump" | cut -f1))"
