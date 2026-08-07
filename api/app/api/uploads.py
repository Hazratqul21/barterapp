from __future__ import annotations

import io
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.security import current_user
from app.models.user import User
from app.schemas.common import ApiModel

router = APIRouter(prefix="/uploads", tags=["uploads"])

#: Anything larger than this is a photo straight off a phone camera that nobody
#: needs at full size; it is rejected before it is decoded, not after.
MAX_UPLOAD_BYTES = 12 * 1024 * 1024

#: Longest edge after resizing. Big enough for a full-width listing photo on a
#: 3x screen, small enough that a feed of twenty of them loads on mobile data.
MAX_EDGE = 1600

#: JPEG quality. The business plan asks for photos around 200 KB; at this
#: quality a 1600px edge lands close to that for typical subjects.
JPEG_QUALITY = 82


class UploadResult(ApiModel):
    #: Absolute, so the client can hand it straight to an image widget.
    url: str
    width: int
    height: int
    bytes: int


def _process(raw: bytes) -> tuple[bytes, int, int]:
    """
    Decode, flatten and shrink an uploaded photo.

    Decoding is also the validation: a file that Pillow cannot open is not an
    image, whatever its name or declared content type says. That matters because
    these files are served back out over HTTP, and trusting the client's label
    is how an upload endpoint becomes a way to host someone else's payload.
    """
    try:
        image = Image.open(io.BytesIO(raw))
        image.load()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Bu fayl rasm emas. JPG yoki PNG yuklang.",
        )

    # Phone photos carry an orientation tag instead of rotated pixels; without
    # this every second listing arrives sideways.
    from PIL import ImageOps

    image = ImageOps.exif_transpose(image)

    if image.mode in ("RGBA", "LA", "P"):
        canvas = Image.new("RGB", image.size, (255, 255, 255))
        converted = image.convert("RGBA")
        canvas.paste(converted, mask=converted.split()[-1])
        image = canvas
    elif image.mode != "RGB":
        image = image.convert("RGB")

    image.thumbnail((MAX_EDGE, MAX_EDGE), Image.LANCZOS)

    buffer = io.BytesIO()
    # No EXIF is written back out: the original often carries GPS coordinates,
    # and a listing photo should not tell strangers where the owner lives.
    image.save(buffer, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    return buffer.getvalue(), image.width, image.height


@router.post("", response_model=UploadResult, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    request: Request,
    file: UploadFile = File(...),
    me: User = Depends(current_user),
) -> UploadResult:
    """
    Take a photo and give back a URL a listing can point at.

    Listings used to accept a URL typed by hand, which works for a seeded demo
    and for nobody else: the person with a spare laptop photographs it, they do
    not host it somewhere first.
    """
    raw = await file.read()
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Fayl bo‘sh.")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            "Rasm juda katta. 12 MB dan kichik rasm yuklang.",
        )

    processed, width, height = _process(raw)

    # Named by the server, never by the client: an uploaded filename is
    # attacker-controlled text and has no business deciding a path on disk.
    name = f"{uuid.uuid4().hex}.jpg"
    destination = settings.media_root / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(processed)

    return UploadResult(
        url=str(request.base_url).rstrip("/") + f"{settings.media_url_prefix}/{name}",
        width=width,
        height=height,
        bytes=len(processed),
    )
