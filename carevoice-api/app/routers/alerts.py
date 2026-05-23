from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import AlertLevel, AlertRecord, Senior
from ..schemas import AlertOut, EscalationStep

router = APIRouter(prefix="/api/alerts", tags=["alerts"])

# Escalation ladder per level: (label, minutes after the alert was triggered).
_LADDER: dict[str, list[tuple[str, int]]] = {
    "info": [
        ("WhatsApp nudge sent", 0),
    ],
    "concern": [
        ("WhatsApp nudge sent", 0),
        ("Caregiver notified (app + daily email)", 0),
    ],
    "urgent": [
        ("No response — caregiver notified", 0),
        ("SMS sent to caregiver", 5),
        ("Calling caregiver", 15),
        ("RC volunteer alerted", 30),
    ],
    "emergency": [
        ("Distress detected — caregiver notified", 0),
        ("SMS sent to caregiver", 1),
        ("Calling caregiver", 3),
        ("RC volunteer dispatched", 10),
        ("Emergency services (SCDF) alerted", 20),
    ],
}


def _escalation(a: AlertRecord) -> list[EscalationStep]:
    steps = _LADDER.get(str(a.level), [])
    # A step has happened once its scheduled time has passed; if the alert was
    # resolved, escalation stops at the resolution time.
    now = datetime.now(timezone.utc)
    effective = a.resolved_at or now
    out: list[EscalationStep] = []
    for label, offset in steps:
        scheduled = a.triggered_at + timedelta(minutes=offset)
        done = scheduled <= effective
        out.append(EscalationStep(label=label, done=done, at=scheduled if done else None))
    return out


def _to_out(a: AlertRecord) -> AlertOut:
    return AlertOut(
        id=a.id,
        senior_id=a.senior_id,
        senior_name=a.senior.name,
        level=AlertLevel(a.level),
        trigger=a.trigger,
        action=a.action,
        responded_by=a.responded_by,
        triggered_at=a.triggered_at,
        resolved_at=a.resolved_at,
        escalation=_escalation(a),
    )


@router.get("", response_model=list[AlertOut])
def list_alerts(
    state: Literal["all", "active", "resolved"] = Query("all"),
    db: Session = Depends(get_db),
) -> list[AlertOut]:
    q = db.query(AlertRecord).options(joinedload(AlertRecord.senior))
    if state == "active":
        q = q.filter(AlertRecord.resolved_at.is_(None))
    elif state == "resolved":
        q = q.filter(AlertRecord.resolved_at.is_not(None))
    rows = q.order_by(AlertRecord.triggered_at.desc()).all()
    return [_to_out(a) for a in rows]


@router.post("/{alert_id}/ack", response_model=AlertOut)
def ack_alert(
    alert_id: str,
    responded_by: str = Query("Caregiver"),
    db: Session = Depends(get_db),
) -> AlertOut:
    a = (
        db.query(AlertRecord)
        .options(joinedload(AlertRecord.senior))
        .filter(AlertRecord.id == alert_id)
        .one_or_none()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="alert not found")
    a.resolved_at = datetime.now(timezone.utc)
    a.responded_by = responded_by

    # If this was the senior's last unresolved alert, reset their status to OK.
    still_active = (
        db.query(AlertRecord)
        .filter(AlertRecord.senior_id == a.senior_id, AlertRecord.resolved_at.is_(None), AlertRecord.id != a.id)
        .count()
    )
    if still_active == 0:
        senior = db.query(Senior).filter(Senior.id == a.senior_id).one()
        senior.status = AlertLevel.info.value

    db.commit()
    db.refresh(a)
    return _to_out(a)
