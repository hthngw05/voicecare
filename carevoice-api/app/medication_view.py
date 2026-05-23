from datetime import datetime, timedelta, timezone

from .models import Medication, MedicationAlarm
from .schemas import AlarmOut, MedicationOut

SGT = timezone(timedelta(hours=8))


def alarm_status(a: MedicationAlarm) -> str:
    """Per-alarm status for today (SGT):
    - done:      reminded today and the senior responded
    - awaiting:  reminded today, no response yet
    - scheduled: not yet reminded today (upcoming)
    """
    today = datetime.now(SGT).date()
    if a.last_reminded_on == today:
        return "done" if a.acknowledged else "awaiting"
    return "scheduled"


def alarm_to_out(a: MedicationAlarm) -> AlarmOut:
    return AlarmOut(id=a.id, time=a.time, enabled=a.enabled, status=alarm_status(a))


def med_to_out(m: Medication) -> MedicationOut:
    return MedicationOut(
        id=m.id,
        name=m.name,
        dose=m.dose,
        taken_today=m.taken_today,
        has_photo=bool(m.photo),
        alarms=[alarm_to_out(a) for a in m.alarms],
    )
