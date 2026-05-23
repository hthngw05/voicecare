import base64
import re

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..medication_view import med_to_out
from ..models import Medication, MedicationAlarm, Senior
from ..schemas import (
    AlarmCreate,
    AlarmUpdate,
    MedicationCreate,
    MedicationOut,
    OcrRequest,
    OcrResult,
)
from .. import ocr

router = APIRouter(tags=["medications"])

_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


def _valid_time(t: str) -> str:
    t = (t or "").strip()
    if not _HHMM.match(t):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"time must be HH:MM (24h), got '{t}'",
        )
    return t


def _load_med(db: Session, med_id: int) -> Medication:
    med = (
        db.query(Medication)
        .options(selectinload(Medication.alarms))
        .filter(Medication.id == med_id)
        .one_or_none()
    )
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="medication not found")
    return med


@router.post("/api/medications/ocr", response_model=OcrResult)
def ocr_medication(body: OcrRequest) -> OcrResult:
    """Read a medication photo with Gemini Vision → suggested name/dose/times."""
    try:
        image = base64.b64decode(body.photo)
    except Exception:
        raise HTTPException(status_code=422, detail="bad image data")
    try:
        result = ocr.extract_medication(image, body.photo_mime)
    except ocr.OcrRateLimited as e:
        raise HTTPException(status_code=429, detail=str(e))
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Couldn't read the photo: {e}")
    return OcrResult(**result)


@router.post("/api/seniors/{senior_id}/medications", response_model=MedicationOut, status_code=201)
def add_medication(senior_id: str, body: MedicationCreate, db: Session = Depends(get_db)) -> MedicationOut:
    if db.query(Senior.id).filter(Senior.id == senior_id).first() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="senior not found")
    if not body.name.strip() or not body.dose.strip():
        raise HTTPException(status_code=422, detail="name and dose are required")

    med = Medication(
        senior_id=senior_id,
        name=body.name.strip(),
        dose=body.dose.strip(),
        taken_today=False,
        photo=body.photo or None,
        photo_mime=body.photo_mime or None,
    )
    for t in body.times:
        med.alarms.append(MedicationAlarm(time=_valid_time(t), enabled=True))
    db.add(med)
    db.commit()
    db.refresh(med)
    return med_to_out(med)


class PhotoBody(BaseModel):
    photo: str            # base64 (no data: prefix)
    photo_mime: str = "image/jpeg"


@router.put("/api/medications/{med_id}/photo", response_model=MedicationOut)
def set_photo(med_id: int, body: PhotoBody, db: Session = Depends(get_db)) -> MedicationOut:
    med = _load_med(db, med_id)
    med.photo = body.photo
    med.photo_mime = body.photo_mime
    db.commit()
    db.refresh(med)
    return med_to_out(med)


@router.get("/api/medications/{med_id}/photo")
def get_photo(med_id: int, db: Session = Depends(get_db)) -> Response:
    med = db.query(Medication).filter(Medication.id == med_id).one_or_none()
    if med is None or not med.photo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no photo")
    try:
        data = base64.b64decode(med.photo)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="bad image data")
    return Response(content=data, media_type=med.photo_mime or "image/jpeg")


@router.delete("/api/medications/{med_id}", status_code=204)
def delete_medication(med_id: int, db: Session = Depends(get_db)) -> None:
    med = db.query(Medication).filter(Medication.id == med_id).one_or_none()
    if med is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="medication not found")
    db.delete(med)
    db.commit()


@router.post("/api/medications/{med_id}/alarms", response_model=MedicationOut, status_code=201)
def add_alarm(med_id: int, body: AlarmCreate, db: Session = Depends(get_db)) -> MedicationOut:
    med = _load_med(db, med_id)
    med.alarms.append(MedicationAlarm(time=_valid_time(body.time), enabled=True))
    db.commit()
    db.refresh(med)
    return med_to_out(med)


@router.patch("/api/alarms/{alarm_id}", response_model=MedicationOut)
def update_alarm(alarm_id: int, body: AlarmUpdate, db: Session = Depends(get_db)) -> MedicationOut:
    alarm = db.query(MedicationAlarm).filter(MedicationAlarm.id == alarm_id).one_or_none()
    if alarm is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="alarm not found")
    if body.time is not None:
        alarm.time = _valid_time(body.time)
        # Changing the time re-arms the alarm for today.
        alarm.last_reminded_on = None
        alarm.last_reminded_at = None
        alarm.followups = 0
        alarm.acknowledged = False
    if body.enabled is not None:
        alarm.enabled = body.enabled
    db.commit()
    return med_to_out(_load_med(db, alarm.medication_id))


@router.delete("/api/alarms/{alarm_id}", status_code=204)
def delete_alarm(alarm_id: int, db: Session = Depends(get_db)) -> None:
    alarm = db.query(MedicationAlarm).filter(MedicationAlarm.id == alarm_id).one_or_none()
    if alarm is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="alarm not found")
    db.delete(alarm)
    db.commit()
