from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import account, auth, chat, listings, offers, users
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


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
