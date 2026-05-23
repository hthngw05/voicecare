import json
import time

import requests
from datetime import datetime

from fastapi import APIRouter

from ..schemas import EventOut

router = APIRouter(prefix="/api/events", tags=["events"])

# Live source: Eventbrite "seniors" events in Singapore. Note this scrapes the
# page's embedded data (Eventbrite has no public search API), so it can break if
# their page changes — hence the curated fallback below.
_SOURCE_URL = "https://www.eventbrite.sg/d/singapore/seniors/"
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124 Safari/537.36"
    ),
    "Accept-Language": "en-SG,en;q=0.9",
}
_TTL_SECONDS = 3600  # cache for an hour
_cache: dict = {"events": None, "at": 0.0}

# Curated fallback (used if the live fetch fails) — local Tampines activities.
_FALLBACK: list[EventOut] = [
    EventOut(id="e1", title="Morning Tai Chi @ Tampines Central Park",
             date="Every Mon, Wed, Fri", time="07:30 AM", location="Tampines Central Park",
             category="Exercise", description="Gentle group tai chi for seniors. Free, no registration needed."),
    EventOut(id="e2", title="Kopi & Chat Session", date="Sat, 24 May", time="10:00 AM",
             location="Tampines East CC", category="Social",
             description="Casual coffee morning to meet neighbours. Dialect-friendly volunteers on hand."),
    EventOut(id="e3", title="Free Health Screening", date="Sun, 25 May", time="09:00 AM",
             location="Our Tampines Hub, Community Care", category="Health",
             description="Blood pressure, blood sugar and BMI checks. Bring your ID."),
    EventOut(id="e4", title="Hokkien Karaoke Afternoon", date="Wed, 28 May", time="02:00 PM",
             location="Tampines North CC", category="Social",
             description="Sing-along session with familiar oldies. Light refreshments provided."),
    EventOut(id="e5", title="Smartphone & Scam Awareness Workshop", date="Fri, 30 May", time="03:00 PM",
             location="Tampines Regional Library", category="Learning",
             description="Learn to spot scams and use WhatsApp safely. Hands-on help for seniors."),
]


def _fmt_date(d: str) -> str:
    try:
        return datetime.strptime(d, "%Y-%m-%d").strftime("%a, %d %b")
    except Exception:
        return d or ""


def _fmt_time(t: str) -> str:
    try:
        h, m = t.split(":")
        h, m = int(h), int(m)
        ampm = "AM" if h < 12 else "PM"
        h12 = ((h + 11) % 12) + 1
        return f"{h12}:{m:02d} {ampm}"
    except Exception:
        return t or ""


def _fetch_eventbrite() -> list[EventOut]:
    r = requests.get(_SOURCE_URL, headers=_HEADERS, timeout=15)
    r.raise_for_status()
    html = r.text
    i = html.find("window.__SERVER_DATA__")
    if i < 0:
        raise ValueError("server data not found")
    eq = html.find("=", i) + 1
    data, _ = json.JSONDecoder().raw_decode(html[eq:].lstrip())
    results = data["search_data"]["events"]["results"]

    out: list[EventOut] = []
    for ev in results[:12]:
        venue = ev.get("primary_venue") or {}
        addr = (venue.get("address") or {}).get("localized_address_display") or ""
        if ev.get("is_online_event"):
            location = "Online"
        else:
            location = venue.get("name") or addr or "Singapore"
        out.append(EventOut(
            id=str(ev.get("id") or ev.get("eid") or ev.get("url") or len(out)),
            title=ev.get("name") or "Event",
            date=_fmt_date(ev.get("start_date") or ""),
            time=_fmt_time(ev.get("start_time") or ""),
            location=location,
            category="Community",
            description=(ev.get("summary") or "").strip(),
            url=ev.get("url") or "",
        ))
    return out


def _get_events() -> list[EventOut]:
    now = time.time()
    if _cache["events"] and (now - _cache["at"]) < _TTL_SECONDS:
        return _cache["events"]
    try:
        events = _fetch_eventbrite()
        if events:
            _cache["events"] = events
            _cache["at"] = now
            return events
    except Exception as e:  # noqa: BLE001
        print(f"[events] live fetch failed, using fallback: {e}")
    # Serve stale cache if we have it, else the curated fallback.
    return _cache["events"] or _FALLBACK


@router.get("", response_model=list[EventOut])
def list_events() -> list[EventOut]:
    return _get_events()
