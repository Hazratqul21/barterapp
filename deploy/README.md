# MAB'ni serverga chiqarish

Hammasi noutbukdan, bitta skript bilan bajariladi: `deploy/deploy.sh`.

```
mab.uz        → sayt (Flutter web)      /var/www/mab
api.mab.uz    → API (FastAPI, uvicorn)  /opt/mab/api  → 127.0.0.1:8010
              → admin panel             https://api.mab.uz/admin
              → Payme endpoint          https://api.mab.uz/payments/payme
PostgreSQL    → baza "mab", faqat lokal
```

## 0. DNS (domen panelida)

| Yozuv | Nom | Qiymat |
|---|---|---|
| A | `mab.uz` | server IP |
| A | `www.mab.uz` | server IP |
| A | `api.mab.uz` | server IP |

DNS tarqalishi bir necha daqiqadan bir necha soatgacha oladi. Tekshirish: `dig +short api.mab.uz`.

## 1. Server manzili va SSH kalit (bir marta)

```sh
cd ~/barter-platform
echo 'LOGIN@SERVER_IP' > deploy/.server     # git'ga tushmaydi
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "mab-deploy"
ssh-copy-id "$(cat deploy/.server)"          # parol oxirgi marta so'raladi
ssh "$(cat deploy/.server)" 'sudo -v && echo ok'
```

Kalit ishlagach, parol bilan kirishni o'chirish tavsiya etiladi (serverda `/etc/ssh/sshd_config` → `PasswordAuthentication no`, keyin `sudo systemctl reload ssh`). Buni faqat kalit bilan kirish ishlayotganini tekshirgandan keyin qiling.

## 2. Birinchi o'rnatish

```sh
cd ~/barter-platform
git checkout develop && git pull
EMAIL=siz@mab.uz bash deploy/deploy.sh --setup
```

Skript serverga quyidagilarni o'rnatadi:
- PostgreSQL, Python 3.11+, nginx, certbot va firewall;
- `mab` foydalanuvchisi va `mab` bazasi (parol tasodifiy, `/opt/mab/.db_password`);
- `/opt/mab/api/.env` fayli — `JWT_SECRET` tasodifiy, `APP_ENV=production`;
- systemd: API, har daqiqalik push va kunlik tozalash;
- HTTPS sertifikat (DNS tayyor bo'lsa).

Keyin backend va saytni yuklaydi.

**Muhim.** Production rejimida SMS (Eskiz) sozlanmaguncha API ishga tushmaydi. Sababi oddiy: SMS bo'lmasa hech kim kira olmaydi. Serverda Eskiz ma'lumotini kiriting:

```sh
ssh "$(cat deploy/.server)"
sudo nano /opt/mab/api/.env        # ESKIZ_EMAIL, ESKIZ_PASSWORD
sudo systemctl restart mab-api
curl -s http://127.0.0.1:8010/health
```

Eskiz hali bo'lmasa, vaqtincha `.env` ga `SMS_OPTIONAL=true` yozing. Shunda API SMS'siz ishga tushadi, tasdiqlash kodlari esa faqat server logida ko'rinadi (`sudo journalctl -u mab-api -f | grep "quruq rejim"`). Bu rejimda faqat jamoa kira oladi. Eskiz ulangach qatorni o'chiring.

## 3. Keyingi yangilanishlar

```sh
git checkout develop && git pull
bash deploy/deploy.sh            # API + sayt
bash deploy/deploy.sh --api      # faqat backend
bash deploy/deploy.sh --web      # faqat sayt
```

Migratsiyalar (`alembic upgrade head`) har deployda avtomatik bajariladi.

## Tekshirish va muammolar

```sh
ssh "$(cat deploy/.server)"
sudo systemctl status mab-api
sudo journalctl -u mab-api -n 100 --no-pager      # API loglari
sudo tail -n 50 /var/log/nginx/error.log
```

- **API ishga tushmasa:** loglarda `APP_ENV=production, lekin sozlamalar xavfsiz emas` degan yozuv bo'lsa, ro'yxatdagi har bir bandni `.env` da tuzating.
- **Sertifikat olinmagan bo'lsa:** DNS tayyor bo'lgach `sudo certbot --nginx -d mab.uz -d www.mab.uz -d api.mab.uz --redirect -m <email> --agree-tos -n`.
- **Moderator (admin) huquqi:** `sudo -u mab bash -c 'cd /opt/mab/api && .venv/bin/python -m app.grant_moderator +998XXXXXXXXX'`.

## Admin panelga kirish

1. Saytda yoki ilovada telefon raqamingiz bilan bir marta kiring — hisob yaratiladi.
2. O'sha raqamga moderator huquqini bering (bir marta):
   ```sh
   ssh -t "$(cat deploy/.server)" "sudo -u mab bash -c 'cd /opt/mab/api && .venv/bin/python -m app.grant_moderator +998XXXXXXXXX'"
   ```
3. https://api.mab.uz/admin → raqam → «Kod olish» → SMS kodi → «Kirish».
   `SMS_OPTIONAL=true` bo'lsa kod SMS'da emas, server logida:
   ```sh
   ssh -t "$(cat deploy/.server)" 'sudo journalctl -u mab-api -n 50 --no-pager | grep "quruq rejim"'
   ```

## Huquqiy hujjatlar

Admin panel → **Hujjatlar**. Saqlangan matn darhol https://mab.uz/privacy,
`/terms`, `/offer`, `/delete-account` da chiqadi: nginx bu manzillarni
API'ga yo'naltiradi (`deploy/nginx/mab-legal.conf`). Bu qoida har
deployda o'zi o'rnatiladi; certbot sozlagan HTTPS bloklariga tegilmaydi.

## Zaxira nusxa

Har kuni 03:30 da avtomatik (`mab-backup.timer`): baza (`pg_dump -Fc`) va
`/opt/mab/media` → `/var/backups/mab`, 14 kun saqlanadi. Har deploydan oldin
ham alohida nusxa olinadi (`mab-…-pre-deploy-….dump`).

```sh
sudo mab-backup                                   # qo'lda
ls -lh /var/backups/mab                           # ro'yxat
# Tiklash:
sudo -u postgres pg_restore --clean --if-exists -d mab /var/backups/mab/<fayl>.dump
sudo tar -xzf /var/backups/mab/media-<sana>.tar.gz -C /opt/mab
```

Server butunlay buzilsa ham nusxa qolishi uchun haftada bir marta
noutbukka ko'chirib qo'ying:
`scp -r "$(cat deploy/.server)":/var/backups/mab ~/mab-backups/` (root
egaligida bo'lgani uchun avval `sudo chmod -R a+rX /var/backups/mab` yoki
`sudo cp` bilan uy papkangizga).

## Xavfsizlik — bir martalik qadamlar

1. **SSH faqat kalit bilan** (kalit bilan kirish ishlayotganini tekshirgandan keyin):
   ```sh
   ssh -t "$(cat deploy/.server)" 'printf "PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n" | sudo tee /etc/ssh/sshd_config.d/10-mab.conf && sudo sshd -t && sudo systemctl reload ssh'
   ```
   Keyin server parolini almashtiring: `passwd`.
2. **`.env` ga qo'shing** (`sudo nano /opt/mab/api/.env`, keyin `sudo systemctl restart mab-api`):
   ```
   PUBLIC_API_URL=https://api.mab.uz
   SMS_OPTIONAL_PHONES=["+998XXXXXXXXX"]   # SMS_OPTIONAL paytida kod faqat shu raqamlarga
   ```
3. fail2ban, avtomatik xavfsizlik yangilanishlari va log muddati (14 kun)
   `setup_server.sh` da. Eski serverda bir marta: `sudo apt install -y fail2ban unattended-upgrades`.

Batafsil: [docs/SECURITY-AUDIT-2026-10-21.md](../docs/SECURITY-AUDIT-2026-10-21.md).

Ilova ID'si (`uz.mab.app`) va domenlar haqida: `README.md` → "Domen va identifikatorlar".
