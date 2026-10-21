"""Huquqiy hujjatni ochiq HTML sahifaga aylantirish.

Sahifa serverda tayyorlanadi, Flutter orqali emas: do'konlar (Google Play,
App Store) va Payme tekshiruvchilari havolani oddiy brauzerda ochadi, matn
JavaScript'siz, bir zumda ko'rinishi kerak.

Markdown'da xom HTML o'chiq (`html: False`) va `javascript:` havolalar
rad etiladi — admin panelga kirgan odam ham sahifaga skript qo'ya olmaydi.
"""

from __future__ import annotations

import html
import re
from datetime import datetime

from markdown_it import MarkdownIt

from app.core.config import settings
from app.models.legal import LegalDocument

LOCALES = ("uz", "ru", "en")

#: Bu hujjatlar mab.uz'ning o'zida qisqa manzilga ega (nginx shu ro'yxatni
#: biladi) va o'chirib bo'lmaydi: ilova, do'konlar va Payme ularga havola
#: qiladi. Qolganlari https://mab.uz/legal/<slug> da.
CORE_SLUGS = ("privacy", "terms", "offer", "delete-account")

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,39}$")

#: To'ldirilmagan shablon belgilari: {{KOMPANIYA_NOMI}} va h.k.
PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")

_md = MarkdownIt("commonmark", {"html": False, "linkify": False}).enable("table")

_UI = {
    "uz": {
        "updated": "Oxirgi yangilanish",
        "pdf": "PDF yuklab olish",
        "missing": "Bu hujjatning o'zbekcha matni ko'rsatilmoqda.",
        "home": "Bosh sahifa",
    },
    "ru": {
        "updated": "Последнее обновление",
        "pdf": "Скачать PDF",
        "missing": "Перевод пока не готов — показан текст на узбекском языке.",
        "home": "Главная",
    },
    "en": {
        "updated": "Last updated",
        "pdf": "Download PDF",
        "missing": "No translation yet — showing the Uzbek text.",
        "home": "Home",
    },
}


def public_url(slug: str) -> str:
    base = settings.public_web_url.rstrip("/")
    return f"{base}/{slug}" if slug in CORE_SLUGS else f"{base}/legal/{slug}"


def pick_locale(lang: str | None, accept_language: str | None) -> str:
    if lang in LOCALES:
        return lang
    for part in (accept_language or "").split(","):
        code = part.split(";", 1)[0].strip().lower()[:2]
        if code in LOCALES:
            return code
    return "uz"


def text_for(values: dict, locale: str) -> str:
    return (values.get(locale) or "").strip() or (values.get("uz") or "").strip()


def has_placeholders(doc: LegalDocument) -> bool:
    return any(PLACEHOLDER_RE.search(v or "") for v in doc.body.values())


def _without_heading(text: str) -> str:
    """Sarlavha sahifada alohida chiqadi; matn ham `# ...` bilan boshlansa,
    u ikki marta ko'rinmasin."""
    first, _, rest = text.partition("\n")
    return rest.lstrip("\n") if first.startswith("# ") else text


def _date(value: datetime) -> str:
    return value.strftime("%d.%m.%Y")


def render_page(
    doc: LegalDocument, locale: str, others: list[LegalDocument]
) -> str:
    ui = _UI[locale]
    title = text_for(doc.title, locale)
    translated = bool((doc.body.get(locale) or "").strip())
    body_html = _md.render(_without_heading(text_for(doc.body, locale)))
    esc = html.escape

    langs = " ".join(
        f'<a href="?lang={code}"{" class=on" if code == locale else ""}>'
        f"{code.upper()}</a>"
        for code in LOCALES
    )
    notice = (
        "" if translated or locale == "uz"
        else f'<p class="notice">{esc(ui["missing"])}</p>'
    )
    pdf = (
        f'<a class="pdf" href="{esc(doc.file_url)}" target="_blank" '
        f'rel="noopener">{esc(ui["pdf"])}</a>'
        if doc.file_url else ""
    )
    links = " · ".join(
        f'<a href="{esc(public_url(o.slug))}?lang={locale}">'
        f"{esc(text_for(o.title, locale))}</a>"
        for o in others
        if o.slug != doc.slug
    )
    home = esc(settings.public_web_url)

    return f"""<!doctype html>
<html lang="{locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)} — MAB</title>
<link rel="canonical" href="{esc(public_url(doc.slug))}">
<style>
  :root{{--bg:#F7F6F1;--card:#FFFFFF;--ink:#1B1E10;--soft:#5E6352;--line:#E3E3DA;
         --brand:#353A1E;--accent:#6E7B2F}}
  @media (prefers-color-scheme: dark){{
    :root{{--bg:#16180D;--card:#1F2214;--ink:#EEF0E6;--soft:#A7AC98;--line:#33372A;
           --brand:#C9D38F;--accent:#C9D38F}}
  }}
  *{{box-sizing:border-box}}
  body{{margin:0;background:var(--bg);color:var(--ink);
       font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}}
  header{{max-width:820px;margin:0 auto;padding:20px 16px;display:flex;
         align-items:center;gap:12px}}
  header .logo{{font-weight:900;font-size:22px;letter-spacing:.04em;color:var(--brand);
               text-decoration:none}}
  header span{{flex:1}}
  .langs a{{color:var(--soft);text-decoration:none;font-weight:700;font-size:13px;
           padding:4px 8px;border-radius:8px}}
  .langs a.on{{background:var(--brand);color:var(--bg)}}
  main{{max-width:820px;margin:0 12px 48px;padding:24px 18px;background:var(--card);
       overflow-wrap:anywhere;
       border:1px solid var(--line);border-radius:16px}}
  @media (min-width:640px){{main{{margin:0 auto 48px;padding:40px 48px}}}}
  @media (min-width:640px) and (max-width:844px){{main{{margin:0 12px 48px}}}}
  h1{{font-size:28px;line-height:1.25;margin:0 0 8px}}
  h2{{font-size:20px;margin:32px 0 8px}}
  h3{{font-size:17px;margin:24px 0 6px}}
  .meta{{color:var(--soft);font-size:14px;margin:0 0 20px;display:flex;gap:16px;
        flex-wrap:wrap;align-items:center}}
  .pdf{{color:var(--accent);font-weight:700}}
  .notice{{background:var(--bg);border-radius:10px;padding:10px 14px;color:var(--soft);
          font-size:14px}}
  a{{color:var(--accent)}}
  hr{{border:0;border-top:1px solid var(--line);margin:28px 0}}
  table{{border-collapse:collapse;width:100%;font-size:15px;display:block;overflow-x:auto}}
  th,td{{border:1px solid var(--line);padding:8px 10px;text-align:left;vertical-align:top}}
  blockquote{{margin:16px 0;padding:4px 16px;border-left:3px solid var(--line);
             color:var(--soft)}}
  code{{background:var(--bg);padding:1px 5px;border-radius:5px;font-size:14px}}
  footer{{max-width:820px;margin:0 auto;padding:0 16px 40px;color:var(--soft);
         font-size:14px;text-align:center}}
</style>
</head>
<body>
<header>
  <a class="logo" href="{home}">MAB</a><span></span>
  <nav class="langs">{langs}</nav>
</header>
<main>
  <h1>{esc(title)}</h1>
  <p class="meta"><span>{esc(ui["updated"])}: {_date(doc.updated_at)}</span>{pdf}</p>
  {notice}
  {body_html}
</main>
<footer>{links}{" · " if links else ""}<a href="{home}">{esc(ui["home"])}</a></footer>
</body>
</html>"""
