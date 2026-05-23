import re
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..medication_view import med_to_out
from ..models import AlertLevel, CheckIn, Medication, Senior
from ..schemas import ActiveAlertOut, CheckInOut, SeniorCreate, SeniorOut, SeniorUpdate

_TITLES = {"mr", "mrs", "ms", "mdm", "madam", "miss", "dr", "auntie", "uncle"}


def _initials(name: str) -> str:
    words = [w for w in name.split() if w.lower().strip(".") not in _TITLES]
    letters = [w[0] for w in words if w][:2]
    return ("".join(letters) or name[:2] or "??").upper()

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")
SGT = timezone(timedelta(hours=8))


def _chart_series(checkins: list[CheckIn]) -> tuple[list[float], list[bool], list[str]]:
    """Build last-7-day mood / medication / label series from real check-ins.
    Mood = average sentiment that day (carried forward when a day has none)."""
    today = datetime.now(SGT).date()
    days = [today - timedelta(days=i) for i in range(6, -1, -1)]  # oldest -> today

    sent_by_day: dict = {}
    med_by_day: dict = {}
    for c in checkins:
        d = c.created_at.astimezone(SGT).date()
        sent_by_day.setdefault(d, []).append(c.sentiment_score)
        if c.medication_taken is True:
            med_by_day[d] = True
        elif d not in med_by_day and c.medication_taken is False:
            med_by_day[d] = False

    mood: list[float] = []
    last: float | None = None
    for d in days:
        vals = sent_by_day.get(d)
        if vals:
            last = round(sum(vals) / len(vals), 2)
        mood.append(last if last is not None else 0.6)

    meds = [bool(med_by_day.get(d, False)) for d in days]
    labels = [d.strftime("%a") for d in days]  # Mon, Tue, ...
    return mood, meds, labels

router = APIRouter(prefix="/api/seniors", tags=["seniors"])


def _newest_active_alert(s: Senior) -> ActiveAlertOut | None:
    """Surface the most recent unresolved alert as the senior's `activeAlert`."""
    for a in s.alerts:  # relationship is ordered triggered_at desc
        if a.resolved_at is None:
            return ActiveAlertOut(
                message=a.action or a.trigger,
                level=AlertLevel(a.level),
                triggered_at=a.triggered_at,
            )
    return None


def _to_out(s: Senior) -> SeniorOut:
    mood, meds, labels = _chart_series(s.checkins)
    return SeniorOut(
        id=s.id,
        name=s.name,
        age=s.age,
        address=s.address,
        avatar_initials=s.avatar_initials,
        languages=list(s.languages),
        preferred_check_in_time=s.preferred_check_in_time,
        wellness_enabled=s.wellness_enabled,
        rc_volunteer=s.rc_volunteer,
        phone=s.phone,
        status=AlertLevel(s.status),
        sentiment_score=s.sentiment_score,
        last_check_in_summary=s.last_check_in_summary,
        last_check_in=s.last_check_in,
        active_alert=_newest_active_alert(s),
        medications=[med_to_out(m) for m in s.medications],
        contacts=s.contacts,
        mood_history=mood,
        meds_history=meds,
        chart_labels=labels,
    )


def _query_with_loads(db: Session):
    return db.query(Senior).options(
        selectinload(Senior.medications).selectinload(Medication.alarms),
        selectinload(Senior.contacts),
        selectinload(Senior.alerts),
        selectinload(Senior.checkins),
    )


@router.get("", response_model=list[SeniorOut])
def list_seniors(db: Session = Depends(get_db)) -> list[SeniorOut]:
    rows = _query_with_loads(db).order_by(Senior.name).all()
    return [_to_out(s) for s in rows]


@router.post("", response_model=SeniorOut, status_code=201)
def create_senior(body: SeniorCreate, db: Session = Depends(get_db)) -> SeniorOut:
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="name is required")
    phone = re.sub(r"\D", "", body.phone or "") or None
    if phone and db.query(Senior.id).filter(Senior.phone == phone).first():
        raise HTTPException(status_code=409, detail="a senior with that phone already exists")
    if body.preferred_check_in_time and not _HHMM.match(body.preferred_check_in_time):
        raise HTTPException(status_code=422, detail="preferred_check_in_time must be HH:MM")

    senior = Senior(
        id=f"s_{uuid.uuid4().hex[:8]}",
        name=name,
        age=body.age or 0,
        address=body.address or "",
        avatar_initials=_initials(name),
        languages=[s for s in body.languages if s.strip()],
        preferred_check_in_time=body.preferred_check_in_time or "09:00",
        rc_volunteer=(body.rc_volunteer or None),
        phone=phone,
        wellness_enabled=True,
        status=AlertLevel.info.value,
        sentiment_score=0.6,
        last_check_in_summary="No check-ins yet.",
        last_check_in=datetime.now(SGT),
        mood_history=[],
        meds_history=[],
    )
    db.add(senior)
    db.commit()
    db.refresh(senior)
    return _to_out(senior)


@router.delete("/{senior_id}", status_code=204)
def delete_senior(senior_id: str, db: Session = Depends(get_db)) -> None:
    s = db.query(Senior).filter(Senior.id == senior_id).one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="senior not found")
    db.delete(s)
    db.commit()


@router.get("/{senior_id}", response_model=SeniorOut)
def get_senior(senior_id: str, db: Session = Depends(get_db)) -> SeniorOut:
    s = _query_with_loads(db).filter(Senior.id == senior_id).one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="senior not found")
    return _to_out(s)


@router.patch("/{senior_id}", response_model=SeniorOut)
def update_senior(senior_id: str, body: SeniorUpdate, db: Session = Depends(get_db)) -> SeniorOut:
    s = _query_with_loads(db).filter(Senior.id == senior_id).one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="senior not found")
    if body.preferred_check_in_time is not None:
        t = body.preferred_check_in_time.strip()
        if not _HHMM.match(t):
            raise HTTPException(status_code=422, detail="preferred_check_in_time must be HH:MM")
        s.preferred_check_in_time = t
        s.last_wellness_on = None  # re-arm today's wellness check-in
    if body.wellness_enabled is not None:
        s.wellness_enabled = body.wellness_enabled
    db.commit()
    db.refresh(s)
    return _to_out(s)


@router.get("/{senior_id}/checkins", response_model=list[CheckInOut])
def list_checkins(
    senior_id: str,
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[CheckIn]:
    exists = db.query(Senior.id).filter(Senior.id == senior_id).first()
    if exists is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="senior not found")
    return (
        db.query(CheckIn)
        .filter(CheckIn.senior_id == senior_id)
        .order_by(CheckIn.created_at.desc())
        .limit(limit)
        .all()
    )
