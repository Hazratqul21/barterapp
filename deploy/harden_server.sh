#!/usr/bin/env bash
# SSH (faqat kalit), fail2ban, avtomatik xavfsizlik yangilanishlari.
#   sudo KEY_LOGIN_VERIFIED=1 bash harden_server.sh
# Avval boshqa oynada SSH kalit bilan kirish ishlashini tekshiring.
set -euo pipefail
[ "$(id -u)" = 0 ]
[ "${KEY_LOGIN_VERIFIED:-}" = 1 ] || { echo 'Verify a separate SSH key session first.'; exit 1; }
umask 077
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP=/var/backups/mab/hardening-$STAMP
mkdir -p "$BACKUP"
cp -a /etc/nginx /etc/ssh/sshd_config /etc/ssh/sshd_config.d /etc/systemd/system/mab-api.service /opt/mab/api/.env "$BACKUP/"
sudo -u postgres pg_dump -Fc mab > "$BACKUP/database.dump"
pg_restore --list "$BACKUP/database.dump" >/dev/null
printf 'Backup: %s\n' "$BACKUP"

cat > /etc/ssh/sshd_config.d/00-mab-hardening.conf <<'EOF'
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF
sshd -t
systemctl reload ssh

# nginx sarlavhalari, systemd himoyasi va kunlik zaxira endi har deployda
# remote_install.sh orqali o'rnatiladi (deploy/nginx, deploy/systemd,
# deploy/backup.sh) — bu yerda faqat SSH va fail2ban.

export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null
apt-get install -y -q fail2ban unattended-upgrades >/dev/null
cat > /etc/fail2ban/jail.d/mab-sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# Log muddati: kirish kodlari (SMS_OPTIONAL paytida) uzoq saqlanmasin.
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nMaxRetentionSec=14day\n' > /etc/systemd/journald.conf.d/mab.conf
systemctl restart systemd-journald

printf 'Hardening complete. Reboot remains a scheduled manual step.\n'
