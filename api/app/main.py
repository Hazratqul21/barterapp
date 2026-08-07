from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import account, auth, chat, listings, offers, uploads, users
from app.core.config import settings

app = FastAPI(
    title="BarterApp API",
    version="0.1.0",
    description=(
        "Cash-free barter marketplace. Every response is already in one language — "
        "send Accept-Language: uz | ru | en."
    ),
)

app.add_middleware(
    CORSMiddleware,
    # Flutter web picks a fresh port on every run, and reaches the host as both
    # localhost and 127.0.0.1 depending on how it was launched.
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
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

# Uploaded photos are served straight off disk. The directory is created here
# rather than on first upload so a fresh checkout can serve `/media` without
# waiting for someone to post a listing.
settings.media_root.mkdir(parents=True, exist_ok=True)
app.mount(
    settings.media_url_prefix,
    StaticFiles(directory=settings.media_root),
    name="media",
)


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
