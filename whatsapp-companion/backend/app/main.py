"""
CareVoice WhatsApp Chatbot Backend
Handles incoming messages and transcribes voice messages using Whisper
Now with Gemini AI for natural conversations
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import requests
import base64
import json
import os
import re
import asyncio
from datetime import datetime, timezone, timedelta

SGT = timezone(timedelta(hours=8))

# Optional self-test mode: set SELF_TEST_NUMBER to your own WhatsApp number
# (digits only, e.g. 6591234567) to test by messaging YOURSELF. In this mode the
# backend only handles your self-chat, records the check-in, and does NOT reply
# (so there's no auto-reply loop and your other chats are untouched).
SELF_TEST_NUMBER = re.sub(r"\D", "", os.getenv("SELF_TEST_NUMBER", ""))

# Loop protection: remember the IDs and text of messages WE send, so when they
# echo back through the webhook (fromMe=true, especially in self-test self-chat)
# we don't re-process them and reply again forever.
import collections  # noqa: E402
import random  # noqa: E402
_sent_msg_ids = collections.deque(maxlen=300)
_sent_msg_id_set: set[str] = set()
_sent_msg_texts = collections.deque(maxlen=50)


def _remember_sent(msg_id: str | None, text: str | None):
    if msg_id:
        if len(_sent_msg_ids) == _sent_msg_ids.maxlen:
            _sent_msg_id_set.discard(_sent_msg_ids.popleft())
        _sent_msg_ids.append(msg_id)
        _sent_msg_id_set.add(msg_id)
    if text:
        _sent_msg_texts.append(text.strip())


def _is_own_echo(msg_id: str | None, text: str | None) -> bool:
    if msg_id and msg_id in _sent_msg_id_set:
        return True
    if text and text.strip() in _sent_msg_texts:
        return True
    return False


_TITLES = {"mr", "mrs", "ms", "mdm", "madam", "miss", "dr", "auntie", "uncle"}

# Varied fallback phrasings (used if Gemini is unavailable). {name} is filled in.
_REPLY_TEMPLATES = {
    "info": [
        "Lovely to hear from you, {name}! So glad you're doing well today. 💚",
        "Thanks for checking in, {name}. Wonderful that you're feeling good! 💚",
        "Good to hear you're well, {name}. Have a lovely day! 💚",
        "That's great, {name}! Keep it up and take care. 💚",
    ],
    "concern": [
        "Thanks for letting me know, {name}. I've told your caregiver you're not feeling your best — hang in there. 💛",
        "I hear you, {name}. I've let your family know so they can check on you. Rest well today. 💛",
        "Sorry you're not feeling great, {name}. Your caregiver has been notified. Be gentle with yourself. 💛",
    ],
    "urgent": [
        "Thank you for telling me, {name}. I've asked your caregiver to check on you right away. ⚠️",
        "I'm a little worried for you, {name}. Your caregiver has been notified to come see you soon. ⚠️",
    ],
    "emergency": [
        "Stay calm, {name} — I've alerted your caregiver and emergency help right away. Help is on the way. 🚨",
        "Help is coming, {name}. I've notified your caregiver and emergency contacts immediately. Stay where you are. 🚨",
    ],
}


def friendly_name(full_name: str | None) -> str:
    """Turn 'Mr Tan Boon Huat' -> 'Mr Tan'; fall back to 'there'."""
    if not full_name or full_name.lower().startswith("new senior"):
        return "there"
    parts = full_name.split()
    if parts and parts[0].lower().strip(".") in _TITLES and len(parts) >= 2:
        return f"{parts[0]} {parts[1]}"
    return parts[0] if parts else "there"


def build_reply(senior_name: str | None, text: str, level: str) -> str:
    """Generate a warm, personal, dynamic reply. Uses Gemini when available,
    matching the sender's language; falls back to a varied template."""
    name = friendly_name(senior_name)
    if os.getenv("GOOGLE_API_KEY"):
        try:
            prompt = (
                "You are CareVoice, a warm and caring companion checking in on an "
                f"elderly person named {name} who lives alone in Singapore.\n"
                f"They just sent this message: \"{text}\"\n"
                f"Their wellbeing reading is: {level}.\n\n"
                "Write a SHORT reply (1-2 sentences) like a kind family member. "
                f"Address them by name ({name}). Acknowledge what they actually said. "
                "If the level is urgent or emergency, calmly reassure them that their "
                "caregiver and help have been notified and are on the way. "
                "If they used Malay, Mandarin, Tamil, Hokkien or Singlish, reply in that "
                "same language. Keep it warm, simple and natural. No markdown."
            )
            resp = model.generate_content(prompt)
            out = (resp.text or "").strip()
            if out:
                return out
        except Exception as e:  # noqa: BLE001
            print(f"[reply] Gemini personal reply failed, using template: {e}")
    return random.choice(_REPLY_TEMPLATES.get(level, _REPLY_TEMPLATES["info"])).format(name=name)

# Add Gemini imports
import google.generativeai as genai
from dotenv import load_dotenv

# Wellness analysis + persistence into the shared CareVoice database.
from app import analysis
from app import carevoice_db

app = FastAPI(title="CareVoice WhatsApp Chatbot")

# Configuration
EVOLUTION_URL = "http://evolution:8080"
EVOLUTION_API_KEY = "supersecretkey123"
WHISPER_URL = "http://whisper:8001" 
INSTANCE_NAME = "carevoice"

load_dotenv()
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

model = genai.GenerativeModel("gemini-2.5-flash")


def get_ai_reply(transcribed_text: str) -> str:
    """Get AI response from Gemini"""
    system_prompt = """You are a caring AI companion for seniors living alone.
Your name is CareVoice Assistant.
You help seniors with:
- Medication reminders
- Daily wellness check-ins  
- Emergency assistance (SOS)

Be warm, patient, and concise.
Use simple language that seniors can understand.
Keep responses short (1-2 sentences).

IMPORTANT:
- If they say "help me", "I fell", or mention an emergency, immediately say you are alerting their caregiver.
- If they confirm taking medication, acknowledge and thank them.
- If they say they will take it later, say you will remind them again.
- If they express feeling unwell, show concern and offer to contact their caregiver.

Speak in a friendly, caring tone like a family member would."""

    prompt = f"{system_prompt}\n\nSenior says: {transcribed_text}"
    response = model.generate_content(prompt)
    return response.text


@app.get("/")
async def root():
    return {"message": "CareVoice WhatsApp Chatbot Backend is running"}


@app.get("/health")
async def health():
    return {"status": "healthy", "carevoice_db": carevoice_db.healthcheck()}


def persist_checkin(phone: str, text: str, source: str = "whatsapp") -> dict | None:
    """Analyze a transcribed check-in and store it in the CareVoice DB.

    Never raises — persistence problems must not break the WhatsApp reply.
    """
    if not text or text.strip().lower().startswith("error transcribing"):
        return None
    try:
        result = analysis.analyze(text)
        written = carevoice_db.record_checkin(
            phone=phone, transcript=text, analysis=result, source=source
        )
        print(
            f"[checkin] {written['senior_name']} -> level={written['alert_level']} "
            f"(checkin #{written['checkin_id']}, alert={written['alert_id']})"
        )
        return {**result, **written}
    except Exception as e:  # noqa: BLE001
        print(f"[checkin] failed to persist check-in: {e}")
        return None


class SimulatedCheckin(BaseModel):
    phone: str
    text: str
    source: str = "simulated"


@app.post("/checkin")
async def simulate_checkin(payload: SimulatedCheckin):
    """Test the elderly->app pipeline WITHOUT WhatsApp.

    Example:
      curl -X POST http://localhost:8002/checkin \
           -H "Content-Type: application/json" \
           -d '{"phone":"6591110001","text":"Wa boh sai, I cannot get out of bed"}'
    """
    written = persist_checkin(payload.phone, payload.text, source=payload.source)
    if written is None:
        raise HTTPException(status_code=400, detail="Could not analyze/persist check-in")
    return {"status": "ok", "result": written}


@app.post("/webhook")
async def webhook(request: Request):
    """
    Receive incoming messages from Evolution API
    Handles text messages and voice messages (transcription)
    """
    try:
        data = await request.json()

        # Log received message
        print(f"Received webhook: {json.dumps(data, indent=2)}")

        payload = data.get("data")
        if payload:
            event = str(data.get("event") or "").lower()
            raw = json.dumps(payload).lower()
            # Poll votes arrive as a poll update (often via messages.update).
            if "pollupdate" in raw or "messages.update" in event:
                await handle_poll_vote(payload, raw)
            else:
                await handle_message(payload)

        return {"status": "success"}
    
    except Exception as e:
        print(f"Error processing webhook: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def handle_message(message: dict):
    """Process incoming message"""

    # Get message type
    msg_type = message.get("type")
    key = message.get("key", {})
    from_number = key.get("remoteJid")  # Sender's number
    message_id = key.get("id")  # Message ID for audio download
    from_me = bool(key.get("fromMe"))
    sender_digits = re.sub(r"\D", "", from_number or "")

    # Peek at the text now so we can detect echoes of our own replies.
    _peek = message.get("message", {}) or {}
    _peek_text = (
        _peek.get("conversation")
        or _peek.get("extendedTextMessage", {}).get("text")
        or _peek.get("textMessage", {}).get("text")
    )
    if _is_own_echo(message_id, _peek_text):
        print("Skipping echo of our own sent message (loop protection).")
        return

    if SELF_TEST_NUMBER:
        # Self-test mode: only handle YOUR self-chat. We DO reply now; the echo
        # check above stops the reply from looping back on itself.
        if sender_digits != SELF_TEST_NUMBER:
            return
        reply = True
        print("[self-test] Recording your own message as a check-in.")
    else:
        # Normal mode: ignore the bot's own messages (fromMe) to avoid an
        # infinite auto-reply loop, and reply to incoming messages from others.
        if from_me:
            print("Ignoring own (fromMe) message to avoid reply loop.")
            return
        reply = True

    # Evolution v2 uses `messageType`; older payloads used `type`.
    msg_type = message.get("messageType") or msg_type
    message_content = message.get("message", {}) or {}

    print(f"Processing message from {from_number}, type: {msg_type}, id: {message_id}")

    # Extract text from the common WhatsApp/Baileys shapes:
    #   plain text   -> message.conversation
    #   quoted/long  -> message.extendedTextMessage.text
    #   (legacy)     -> message.textMessage.text
    text = (
        message_content.get("conversation")
        or message_content.get("extendedTextMessage", {}).get("text")
        or message_content.get("textMessage", {}).get("text")
    )
    is_audio = (
        "audioMessage" in message_content
        or msg_type in ("audioMessage", "audio")
    )

    if text:
        await handle_text_message(from_number, text, reply=reply)
    elif is_audio:
        # Voice message - transcribe it
        print("Voice message detected - transcribing...")
        if message_id:
            text = await transcribe_voice_message(message_id)
            print(f"Transcribed text: {text}")
            await handle_text_message(from_number, text, is_voice=True, reply=reply)
        elif reply:
            await send_message(from_number, "Sorry, I couldn't process your voice message.")
    else:
        print(f"Unsupported/empty message (type={msg_type}); skipping.")


async def handle_poll_vote(payload: dict, raw: str):
    """Handle a vote on a medication reminder poll (Taken / Later)."""
    key = payload.get("key", {})
    from_number = key.get("remoteJid") or ""
    msg_id = key.get("id")
    sender = re.sub(r"\D", "", from_number)

    # Ignore our own poll messages echoing back.
    if _is_own_echo(msg_id, None):
        return
    # In self-test mode, only handle your own chat.
    if SELF_TEST_NUMBER and sender != SELF_TEST_NUMBER:
        return

    # Read the actual selected option(s). Evolution decrypts the vote into
    # message.pollUpdateMessage.vote.selectedOptions; fall back to the
    # aggregated pollUpdates (the option whose 'voters' list is non-empty).
    selected: list[str] = []
    try:
        selected = (
            payload.get("message", {})
            .get("pollUpdateMessage", {})
            .get("vote", {})
            .get("selectedOptions")
            or []
        )
    except Exception:
        selected = []
    if not selected:
        for u in payload.get("pollUpdates", []) or []:
            if u.get("voters"):
                selected.append(u.get("name", ""))

    sel_text = " ".join(selected).lower()
    print(f"[poll] selected option(s): {selected!r}")

    if not selected:
        print("[poll] vote cleared / no option selected; ignoring.")
        return

    chose_taken = "taken" in sel_text
    chose_later = "later" in sel_text

    if chose_taken and not chose_later:
        carevoice_db.mark_poll_taken(from_number)
        print("[poll] -> marked TAKEN")
        await send_message(sender or from_number, "Great, thank you! I've noted that down. 👍")
    elif chose_later and not chose_taken:
        carevoice_db.snooze_reminders(from_number)
        print("[poll] -> snoozed (will remind again)")
        await send_message(sender or from_number, "No problem — I'll remind you again shortly. ⏰")
    else:
        print(f"[poll] could not determine choice (taken={chose_taken}, later={chose_later}); "
              "check the payload above to refine parsing.")


async def transcribe_voice_message(message_id: str) -> str:
    """Get audio from Evolution API and transcribe to text using Whisper"""
    
    try:
        # Get audio from Evolution API using message ID
        print(f"Downloading audio from Evolution API: {message_id}")
        
        body = {
            "message": {
                "key": {
                    "id": message_id
                }
            },
            "convertToMp4": False
        }
        
        response = requests.post(
            f"{EVOLUTION_URL}/chat/getBase64FromMediaMessage/{INSTANCE_NAME}",
            json=body,
            headers={"apikey": EVOLUTION_API_KEY},
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            result = response.json()
            print(f"Got audio from Evolution: {result.get('mimetype', 'unknown')}")
            
            # Get base64 audio data
            audio_base64 = result.get("base64")
            
            if not audio_base64:
                raise Exception("No base64 data in response")
            
            # Send to Whisper service
            print("Sending to Whisper for transcription...")
            whisper_response = requests.post(
                f"{WHISPER_URL}/transcribe_bytes",
                json={"base64_audio": audio_base64},
                timeout=120  # 120 second timeout for transcription
            )
            
            if whisper_response.status_code == 200:
                transcription = whisper_response.json()
                text = transcription.get("text", "")
                print(f"Transcription result: '{text}'")
                return text
            else:
                raise Exception(f"Whisper failed: {whisper_response.status_code} - {whisper_response.text}")
        else:
            raise Exception(f"Failed to get audio from Evolution: {response.status_code} - {response.text}")
    
    except Exception as e:
        print(f"Transcription error: {e}")
        return f"Error transcribing audio: {str(e)}"


async def handle_text_message(from_number: str, text: str, is_voice: bool = False, reply: bool = True):
    """Process text message, store the check-in, and (optionally) send an AI reply."""

    # Remove @c.us or @s.whatsapp.net suffix if present
    phone_number = from_number.replace("@c.us", "").replace("@s.whatsapp.net", "")

    print(f"Processing text: {text}")

    # Analyze the check-in and store it in the CareVoice DB so the caregiver
    # app sees the senior's status, mood and any alert. (Safe: never raises.)
    result = persist_checkin(phone_number, text, source="voice" if is_voice else "whatsapp")

    if not reply:
        print("Reply suppressed.")
        return

    # Build a dynamic, personal reply (Gemini when available, else a varied
    # template) based on the senior's name and what they actually said.
    level = (result or {}).get("alert_level", "info")
    senior_name = (result or {}).get("senior_name")
    response_text = build_reply(senior_name, text, level)
    print(f"Reply: {response_text}")

    await send_message(phone_number, response_text)


async def send_message(phone_number: str, message: str):
    """Send WhatsApp text message via Evolution API"""
    
    body = {
        "number": phone_number,
        "text": message
    }
    
    print(f"Sending message to {phone_number}: {message}")
    
    response = requests.post(
        f"{EVOLUTION_URL}/message/sendText/{INSTANCE_NAME}",
        json=body,
        headers={"apikey": EVOLUTION_API_KEY},
        timeout=30
    )

    if response.status_code in (200, 201):
        # Remember this outgoing message so its webhook echo is ignored
        # (prevents an auto-reply loop, especially in self-test self-chat).
        msg_id = None
        try:
            msg_id = (response.json() or {}).get("key", {}).get("id")
        except Exception:
            pass
        _remember_sent(msg_id, message)
        print("Message sent successfully")
    else:
        print(f"Failed to send message: {response.status_code} - {response.text}")


# --------------------------------------------------------------------------
# Medication reminder scheduler
# --------------------------------------------------------------------------
# Medication reminder poll options. The distinct words "taken" / "later" let us
# recognise the vote when it comes back through the webhook.
POLL_TAKEN = "✅ Yes, I've taken it"
POLL_LATER = "⏰ I'll take it later"


async def send_media(phone_number: str, media_b64: str, mimetype: str, caption: str = ""):
    """Send an image via Evolution (base64). Best-effort; never raises."""
    body = {
        "number": phone_number,
        "mediatype": "image",
        "mimetype": mimetype or "image/jpeg",
        "media": media_b64,
        "caption": caption,
        "fileName": "medication.jpg",
    }
    print(f"Sending media (image) to {phone_number}")
    try:
        resp = requests.post(
            f"{EVOLUTION_URL}/message/sendMedia/{INSTANCE_NAME}",
            json=body,
            headers={"apikey": EVOLUTION_API_KEY},
            timeout=60,
        )
        if resp.status_code in (200, 201):
            try:
                _remember_sent((resp.json() or {}).get("key", {}).get("id"), None)
            except Exception:
                pass
            print("Media sent successfully")
        else:
            print(f"Failed to send media: {resp.status_code} - {resp.text[:200]}")
    except Exception as e:  # noqa: BLE001
        print(f"send_media error: {e}")


async def send_poll(phone_number: str, question: str, options: list[str]) -> bool:
    """Send a WhatsApp poll via Evolution. Returns True on success."""
    body = {
        "number": phone_number,
        "name": question,
        "selectableCount": 1,
        "values": options,
    }
    print(f"Sending poll to {phone_number}: {question}")
    try:
        resp = requests.post(
            f"{EVOLUTION_URL}/message/sendPoll/{INSTANCE_NAME}",
            json=body,
            headers={"apikey": EVOLUTION_API_KEY},
            timeout=30,
        )
        if resp.status_code in (200, 201):
            msg_id = None
            try:
                msg_id = (resp.json() or {}).get("key", {}).get("id")
            except Exception:
                pass
            _remember_sent(msg_id, question)
            print("Poll sent successfully")
            return True
        print(f"Failed to send poll: {resp.status_code} - {resp.text}")
        return False
    except Exception as e:  # noqa: BLE001
        print(f"send_poll error: {e}")
        return False


def _reminder_text(senior_name: str | None, med: str, dose: str, kind: str = "initial") -> str:
    name = friendly_name(senior_name)
    if kind == "followup":
        return (
            f"💊 Just checking again, {name} — have you taken your {med} ({dose}) yet? "
            "Please reply 'taken' once you have. 🙂"
        )
    return (
        f"💊 Reminder, {name}: it's time to take your {med} ({dose}). "
        "Reply 'taken' once you've had it. 🙂"
    )


def _greeting() -> str:
    h = datetime.now(SGT).hour
    if h < 12:
        return "Good morning"
    if h < 18:
        return "Good afternoon"
    return "Good evening"


def _wellness_text(senior_name: str | None) -> str:
    name = friendly_name(senior_name)
    return (
        f"{_greeting()}, {name}! 🌅 How are you feeling today? "
        "Reply with a voice note or a message — I'd love to hear from you."
    )


async def _reminder_loop():
    """Every 30s, send due medication reminders and daily wellness check-ins."""
    await asyncio.sleep(5)  # let the app settle
    print("[reminder] scheduler started.")
    while True:
        try:
            for r in carevoice_db.due_reminders():
                phone = re.sub(r"\D", "", r.get("phone") or "")
                if not phone:
                    continue
                kind = r.get("kind", "initial")
                text = _reminder_text(r.get("senior_name"), r["name"], r["dose"], kind)
                print(
                    f"[reminder] Sending {kind} {r['name']} ({r['time']}) reminder poll "
                    f"to {r.get('senior_name')} ({phone})"
                )
                # If the medicine has a photo, send it just before the poll so
                # the senior sees what to take (a poll itself can't hold media).
                if r.get("photo"):
                    await send_media(
                        phone, r["photo"], r.get("photo_mime") or "image/jpeg",
                        caption=f"💊 {r['name']} ({r['dose']})",
                    )
                # Only mark as reminded if the poll actually went out, so a
                # failed send (e.g. WhatsApp briefly disconnected) is retried.
                if await send_poll(phone, text, [POLL_TAKEN, POLL_LATER]):
                    carevoice_db.mark_reminded(r["alarm_id"], kind)

            # Daily wellness check-in at each senior's preferred time.
            for s in carevoice_db.due_wellness():
                phone = re.sub(r"\D", "", s.get("phone") or "")
                if not phone:
                    continue
                print(f"[wellness] Sending daily check-in to {s.get('name')} ({phone})")
                await send_message(phone, _wellness_text(s.get("name")))
                carevoice_db.mark_wellness_sent(s["id"])
        except Exception as e:  # noqa: BLE001
            print(f"[reminder] loop error: {e}")
        await asyncio.sleep(30)


@app.on_event("startup")
async def _start_reminder_scheduler():
    asyncio.create_task(_reminder_loop())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)