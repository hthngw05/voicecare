"""Read a medication photo with Gemini Vision and return structured fields."""
from __future__ import annotations

import json
import re
import time

from .settings import settings


class OcrRateLimited(Exception):
    """Gemini quota/rate limit hit."""

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")

_PROMPT = (
    "You are reading a photo of a medication (box, blister pack, pharmacy label, "
    "or prescription) for an elderly patient.\n"
    "Extract:\n"
    "- name: the medication name (brand or generic).\n"
    "- dose: how many to take, as a tablet count if shown (e.g. '1 tablet', '2 tablets'). "
    "If only a strength like '500mg' is visible and no count, use '1 tablet'.\n"
    "- times: the clock times of day to take it, as 24-hour HH:MM. If the label gives a "
    "frequency instead of times, convert sensibly: morning=08:00, afternoon=13:00, "
    "evening/night=20:00, 'twice daily'=08:00 and 20:00, 'three times daily'=08:00,13:00,20:00, "
    "'once daily'/'every morning'=08:00.\n\n"
    'Return ONLY strict JSON, no markdown: '
    '{"name": "", "dose": "", "times": ["HH:MM"]}. '
    "Use an empty string / empty list for anything not visible."
)


def extract_medication(image_bytes: bytes, mime: str) -> dict:
    if not settings.google_api_key:
        raise RuntimeError("OCR is not configured (no GOOGLE_API_KEY).")

    import google.generativeai as genai

    genai.configure(api_key=settings.google_api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    # Retry once on a transient error; surface rate limits clearly.
    raw = ""
    last_err: Exception | None = None
    for attempt in range(2):
        try:
            resp = model.generate_content(
                [_PROMPT, {"mime_type": mime or "image/jpeg", "data": image_bytes}]
            )
            raw = (resp.text or "").strip()
            last_err = None
            break
        except Exception as e:  # noqa: BLE001
            last_err = e
            msg = str(e).lower()
            if "429" in msg or "quota" in msg or "rate" in msg or "resource_exhausted" in msg:
                raise OcrRateLimited("AI is busy (rate limit). Please try again in a moment.")
            if attempt == 0:
                time.sleep(2)
    if last_err is not None:
        raise last_err

    raw = re.sub(r"^```(json)?|```$", "", raw, flags=re.MULTILINE).strip()
    data = json.loads(raw)

    name = str(data.get("name") or "").strip()
    dose = str(data.get("dose") or "").strip()
    times: list[str] = []
    for t in data.get("times") or []:
        t = str(t).strip()
        if _HHMM.match(t) and t not in times:
            times.append(t)
    return {"name": name, "dose": dose, "times": times}
