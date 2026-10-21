#!/usr/bin/env bash
# Run as root after independently verifying SSH public-key login.
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

cat > /etc/nginx/conf.d/mab-security.conf <<'EOF'
limit_req_zone $binary_remote_addr zone=mab_auth:10m rate=10r/m;
limit_req_status 429;
# Query parameters may contain one-time WebSocket tickets.
log_format mab_safe '$remote_addr - $remote_user [$time_local] "$request_method $uri $server_protocol" $status $body_bytes_sent';
EOF
cat > /etc/nginx/snippets/mab-security-headers.conf <<'EOF'
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Cross-Origin-Opener-Policy "same-origin-allow-popups" always;
add_header Strict-Transport-Security "max-age=31536000" always;
EOF
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-available/mab.conf')
s=p.read_text()
if 'mab-security-headers.conf' not in s:
 s=s.replace('    server_name ', '    server_tokens off;\n    include /etc/nginx/snippets/mab-security-headers.conf;\n    access_log /var/log/nginx/mab-access.log mab_safe;\n    server_name ')
 s=s.replace('        add_header Cache-Control', '        include /etc/nginx/snippets/mab-security-headers.conf;\n        add_header Cache-Control')
 s=s.replace('    location / {\n        proxy_pass', '''    location ~ /\\. { deny all; }
    location /auth/ {
        limit_req zone=mab_auth burst=10 nodelay;
        proxy_pass http://127.0.0.1:8010;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
    location / {
        proxy_pass''')
 s=s.replace('    root /var/www/mab;', '    location ~ /\\.(?!well-known/) { deny all; }\n    root /var/www/mab;')
 s=s.replace('expires 1h;', 'expires -1;')
 p.write_text(s)
PY
if nginx -t; then systemctl reload nginx; else
 cp "$BACKUP/nginx/sites-available/mab.conf" /etc/nginx/sites-available/mab.conf
 exit 1
fi

mkdir -p /etc/systemd/system/mab-api.service.d
cat > /etc/systemd/system/mab-api.service.d/hardening.conf <<'EOF'
[Service]
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/mab/media
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
UMask=0077
EOF
systemctl daemon-reload
# API restart is performed with the verified application release.

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

cat > /usr/local/sbin/mab-backup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
umask 077
folder=/var/backups/mab/daily/$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$folder"
sudo -u postgres pg_dump -Fc mab > "$folder/database.dump"
pg_restore --list "$folder/database.dump" >/dev/null
tar -C /opt/mab -czf "$folder/files.tar.gz" media api/.env
touch "$folder/complete"
# Retain two weeks of completed local backups only.
find /var/backups/mab/daily -mindepth 2 -maxdepth 2 -name complete -mtime +14 -printf '%h\0' | xargs -0 -r rm -rf --
EOF
chmod 700 /usr/local/sbin/mab-backup
cat > /etc/systemd/system/mab-backup.service <<'EOF'
[Unit]
Description=MAB database and media backup
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mab-backup
UMask=0077
EOF
cat > /etc/systemd/system/mab-backup.timer <<'EOF'
[Unit]
Description=Daily MAB backup
[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=15m
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now mab-backup.timer
systemctl start mab-backup.service
printf 'Hardening complete. Reboot remains a scheduled manual step.\n'
