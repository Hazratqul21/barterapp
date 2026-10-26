import logging
import uuid
from pathlib import Path

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api import (
    account,
    admin,
    billing_admin,
    categories_admin,
    disputes_admin,
    auth,
    chat,
    devices,
    events,
    favorites,
    feed_blocks,
    legal,
    legal_admin,
    listings,
    moderation,
    offers,
    payme,
    payments,
    uploads,
    users,
)
from app.core.config import settings
from app.db.session import SessionLocal

log = logging.getLogger("barter")

app = FastAPI(
    # Productionda ochiq API xaritasi kerak emas: u hujumchiga har endpoint
    # va maydonni tayyor ro'yxat qilib beradi.
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None if settings.is_production else "/redoc",
    openapi_url=None if settings.is_production else "/openapi.json",
    title="MAB API",
    version="0.1.0",
    description=(
        "Cash-free barter marketplace. Every response is already in one language — "
        "send Accept-Language: uz | ru | en."
    ),
)

#: Eng katta so'rov tanasi. Surat chegarasi 12 MB, qolgan hamma narsa —
#: JSON, ya'ni ancha kichik. Zaxira bilan 16 MB.
MAX_BODY_BYTES = 16 * 1024 * 1024


#: Faqat fayl yuklash katta tana oladi. Qolgan hammasi JSON: e'lon, xabar,
#: hodisalar — bir megabaytga bemalol sig'adi. Admin hujjat matni (uch tilda)
#: bir necha megabaytgacha bo'lishi mumkin.
MAX_JSON_BYTES = 1024 * 1024
MAX_ADMIN_BYTES = 4 * 1024 * 1024


def _body_limit(path: str) -> int:
    if (
        path.startswith("/uploads")
        or (path.startswith("/admin/legal/") and path.endswith("/file"))
        or (path.startswith("/admin/categories/") and path.endswith("/image"))
    ):
        return MAX_BODY_BYTES
    if path.startswith("/admin"):
        return MAX_ADMIN_BYTES
    return MAX_JSON_BYTES


@app.middleware("http")
async def limit_body_size(request: Request, call_next) -> Response:
    """
    Juda katta so'rovni o'qishdan **oldin** rad etadi.

    Ilgari 40 MB yuborilsa, server uni to'liq qabul qilib, keyin 12 MB
    chegarasi bo'yicha 413 qaytarardi — ya'ni rad etilgan so'rov ham
    to'liq xotira va diskni band qilardi. Cheklanmagan hujumchi uchun bu
    tekin resurs sarfi edi.

    `Content-Length` ga qaraladi. U yolg'on bo'lishi mumkin, lekin
    ASGI serverining o'z chegarasi ikkinchi qator himoya bo'lib qoladi;
    bu yerdagi tekshiruv esa oddiy holatni arzon to'xtatadi.
    """
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > _body_limit(request.url.path):
        return JSONResponse(
            status_code=413,
            content={"detail": "So'rov juda katta."},
        )
    return await call_next(request)


@app.middleware("http")
async def security_headers(request: Request, call_next) -> Response:
    """
    Har javobga: brauzer turini o'zi "taxmin" qilmasin (nosniff — yuklangan
    fayl HTML bo'lib ochilmasin), yuklangan fayllar sahifa sifatida
    ishlamasin, va productionda faqat HTTPS (HSTS).
    """
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    if request.url.path.startswith(settings.media_url_prefix):
        response.headers.setdefault("Content-Security-Policy", "default-src 'none'; sandbox")
    if settings.is_production:
        response.headers.setdefault("Strict-Transport-Security", "max-age=31536000")
    return response


@app.middleware("http")
async def catch_unhandled(request: Request, call_next) -> Response:
    """
    Turn a crash into an answerable error instead of a silent one.

    Starlette's own 500 is raised *outside* the CORS middleware, so the browser
    never sees `Access-Control-Allow-Origin` on it and reports a CORS failure —
    which is a lie about what went wrong. A dead database read like that, and
    the real `ConnectionRefusedError` was only findable in the server log.

    Registered before the CORS middleware so that it sits inside it: the JSON
    below is a normal response and picks the headers up on the way out. Every
    failure also carries an id, printed here and returned to the caller, so a
    screenshot of the client is enough to find the traceback.
    """
    try:
        return await call_next(request)
    except Exception:
        request_id = uuid.uuid4().hex[:12]
        log.exception(
            "unhandled %s %s (request_id=%s)",
            request.method,
            request.url.path,
            request_id,
        )
        return JSONResponse(
            status_code=500,
            content={
                "detail": "Serverda kutilmagan xatolik. Birozdan so'ng urinib ko'ring.",
                "request_id": request_id,
            },
        )


app.add_middleware(
    CORSMiddleware,
    # Production domains come from configuration. Without this the deployed web
    # build — served from its own host, not localhost — had every request
    # blocked by the browser, because the middleware only ever recognised the
    # dev origins below.
    allow_origins=list(settings.cors_origins),
    # Loopback on any port in development (Flutter web changes port every
    # run); None in production. Never a wildcard, so `allow_credentials=True`
    # stays safe.
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(listings.router)
app.include_router(offers.router)
app.include_router(chat.router)
app.include_router(account.router)
app.include_router(uploads.router)
app.include_router(moderation.router)
app.include_router(devices.router)
app.include_router(favorites.router)
app.include_router(events.router)
app.include_router(feed_blocks.router)
app.include_router(admin.router)
app.include_router(disputes_admin.router)
app.include_router(payments.router)
app.include_router(payme.router)
app.include_router(billing_admin.router)
app.include_router(legal.router)
app.include_router(legal_admin.router)
app.include_router(categories_admin.router)

# Uploaded photos are served straight off disk. The directory is created here
# rather than on first upload so a fresh checkout can serve `/media` without
# waiting for someone to post a listing.
settings.media_root.mkdir(parents=True, exist_ok=True)
app.mount(
    settings.media_url_prefix,
    StaticFiles(directory=settings.media_root),
    name="media",
)


#: Admin paneli — bitta HTML sahifa, backend beradi.
#:
#: Alohida frontend loyihasi emas: panel faqat moderatorlar uchun, sahifa
#: bitta, va uni alohida qurish, joylashtirish va yangilash kerak bo'lsa
#: u har doim API'dan orqada qolardi. Shu yerda turgani esa API bilan
#: birga deploy bo'ladi va hech qachon eskirmaydi.
_ADMIN_PAGE = Path(__file__).resolve().parent / "static" / "admin.html"


#: Panel faqat o'z API'si bilan gaplashadi. Boshqa saytga ramka ichida
#: ko'rsatilmaydi (clickjacking: "hammaga push yuborish" tugmasi), tashqi
#: skript yuklanmaydi. `unsafe-inline` — sahifa ichidagi onclick'lar uchun.
_ADMIN_CSP = (
    "default-src 'self'; script-src 'self' 'unsafe-inline'; "
    "style-src 'self' 'unsafe-inline'; connect-src 'self'; "
    "img-src 'self' https: data:; frame-ancestors 'none'; "
    "base-uri 'none'; form-action 'none'; object-src 'none'"
)


@app.get("/admin", include_in_schema=False)
async def admin_panel() -> FileResponse:
    return FileResponse(
        _ADMIN_PAGE,
        media_type="text/html",
        headers={
            "Content-Security-Policy": _ADMIN_CSP,
            "X-Frame-Options": "DENY",
            "Referrer-Policy": "no-referrer",
            "Cache-Control": "no-store",
        },
    )


@app.get("/health", tags=["meta"])
async def health() -> Response:
    """
    Whether this instance can actually serve, not merely whether it booted.

    The old version returned `ok` unconditionally. When the database container
    stopped, it went on saying `ok` while every real endpoint returned 500 — so
    a load balancer would have kept sending traffic to a process that could not
    answer a single query. The round-trip below is what makes the answer mean
    something; a failure reports 503, which is what takes an instance out of
    rotation.
    """
    try:
        async with SessionLocal() as session:
            await session.execute(text("SELECT 1"))
    except Exception:
        log.exception("health check: database unreachable")
        return JSONResponse(
            status_code=503, content={"status": "degraded", "database": "down"}
        )
    return JSONResponse(content={"status": "ok", "database": "up"})
