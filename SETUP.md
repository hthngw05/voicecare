# CareVoice — Setup Guide

CareVoice is an AI WhatsApp companion for seniors plus a Flutter caregiver app.
A senior sends voice/text WhatsApp messages → they're transcribed, analysed, and
stored → the caregiver sees live status, mood trends, alerts, and medication
reminders in the app.

This guide sets up the whole system on a new machine.

---

## 1. Architecture

```
                         ┌─────────────────────────────┐
   Senior's WhatsApp ───▶│ whatsapp-companion (Docker)  │
   (voice / text)        │  • Evolution API (WhatsApp)  │
                         │  • Whisper (speech-to-text)  │
                         │  • backend (FastAPI)         │
                         └───────────────┬──────────────┘
                                         │ writes check-ins / alerts
                                         ▼
                         ┌─────────────────────────────┐
                         │ PostgreSQL  (shared db)      │
                         └───────────────┬──────────────┘
                                         │ reads
                         ┌───────────────▼──────────────┐
   Caregiver's phone ───▶│ carevoice-api (FastAPI :8000)│
   (caregiver-app)       └──────────────────────────────┘
```

| Component            | Folder                          | Port | Required? |
|----------------------|---------------------------------|------|-----------|
| PostgreSQL           | (system service)                | 5432 | Yes |
| CareVoice API        | `carevoice-api/`                | 8000 | Yes (app reads from it) |
| Flutter caregiver app| `caregiver-app/`                | —    | Yes |
| WhatsApp companion   | `whatsapp-companion/` (Docker)  | 8002 / 8080 / 8001 | Optional* |

\* The app works fully on its own with seeded demo data. The WhatsApp companion
is only needed if you want real voice/text check-ins from a senior's phone.

---

## Features at a glance

**Caregiver app (Flutter)** — tabs: Home, Trends, Alerts, Community, Settings.
- **Home** — live status of each senior, OK/Concern/Urgent counts, a customizable
  **Quick View** (pick up to 2 widgets), and an **add-a-senior** button.
- **Trends** — mood line + medication-compliance bars computed from real check-ins,
  plus a **check-in history** with source tags (🎤 voice / 💬 WhatsApp / 💊 reminder reply).
- **Alerts** — filterable list with a live **escalation timeline** for urgent/emergency.
- **Community** — **live Singapore "seniors" events scraped from Eventbrite** (cached,
  tappable to open; falls back to a curated Tampines list).
- **Senior profile** — daily wellness check-in time, medications with **photo + AI
  "autofill from photo" (Gemini Vision OCR)**, multiple per-medication **alarms** with
  status, tap-to-call contacts, and remove-senior.

**WhatsApp companion (voicecare)** — for a senior's phone:
- Voice/text check-ins → Whisper transcription → Gemini (or offline keyword) analysis → DB.
- Warm, **personalised AI replies** (matches the language they used).
- **Medication reminders as WhatsApp polls** (✅ Taken / ⏰ Later), with the medicine
  **photo sent before the poll**; follow-ups every **10 min** if no answer, **30 min**
  after "Later" (max 4); a "Taken" vote logs a check-in.
- **Daily wellness check-in** at the senior's preferred time.
- **Self-test mode** so you can test with a single number by messaging yourself.

All times are **Singapore time (UTC+8)**.

---

## 2. Prerequisites

### Tools to install

| Tool | Version | Download | Used for |
|------|---------|----------|----------|
| **Flutter SDK** | 3.x (Dart 3.x) | https://docs.flutter.dev/get-started/install | Building/running the caregiver app |
| **Android Studio** | latest | https://developer.android.com/studio | Android emulator + run the app |
| **PostgreSQL** | 14+ (built on 18) | https://www.postgresql.org/download/ | The shared database |
| **Python** | 3.11+ | https://www.python.org/downloads/ (tick **"Add python.exe to PATH"**) | The CareVoice API |
| **Docker Desktop** | latest | https://www.docker.com/products/docker-desktop/ | The WhatsApp companion (optional) |
| **Git** | any | https://git-scm.com/downloads | Cloning the code |

After installing Flutter + Android Studio, run **`flutter doctor`** and resolve
anything it flags (especially "Android toolchain" and accepting Android
licences: `flutter doctor --android-licenses`).

### Accounts / keys you'll need

- **Google AI Studio API key** (free): https://aistudio.google.com → "Get API key".
  Powers the medication **photo OCR autofill** and the WhatsApp companion's AI
  replies/analysis. **Use your own key** — the free tier is rate-limited, so a
  shared key gets throttled. (Everything still works without it, just without the
  AI-smart parts.)
- **A spare WhatsApp number** — *only* if you want the real WhatsApp companion.
  It becomes the "bot"; don't use your primary number (see §6.4).

> Windows examples below use PowerShell. On macOS/Linux use the equivalent
> shell commands (e.g. `source .venv/bin/activate`, `cp` instead of `copy`).

---

## Get the project files & folder layout

Everything lives in **one repository**. Clone it (or copy the folder) anywhere:

```powershell
git clone https://github.com/hthngw05/voicecare.git
cd voicecare
```

Layout:

```
voicecare/                     (repo root)
├─ caregiver-app/              ← Flutter caregiver app
├─ carevoice-api/              ← CareVoice API (FastAPI, port 8000)
├─ whatsapp-companion/         ← WhatsApp companion (Docker): Evolution, Whisper, backend
├─ SETUP.md                    ← this guide
└─ README.md
```

> All commands below assume your shell is **at the repo root** (`voicecare/`)
> unless stated otherwise.

---

## 3. PostgreSQL — create the database

Open `psql` as a superuser (e.g. the `postgres` user) and run:

```sql
CREATE ROLE carevoice WITH LOGIN PASSWORD 'carevoice';
CREATE DATABASE carevoice OWNER carevoice ENCODING 'UTF8';
```

That's it — the API creates all tables automatically.

---

## 4. CareVoice API (`carevoice-api/`)

This is the API the Flutter app talks to. From the repo root:

```powershell
cd carevoice-api
python -m venv .venv
.\.venv\Scripts\Activate.ps1            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt

# Configuration
copy .env.example .env                  # macOS/Linux: cp .env.example .env
# Edit .env if your DB isn't the default localhost/carevoice/carevoice.
```

`.env` contents:

```
DATABASE_URL=postgresql+psycopg://carevoice:carevoice@localhost:5432/carevoice
CORS_ORIGINS=*
GOOGLE_API_KEY=AIza...your_key      # for medication photo OCR autofill (optional)
```

> Without `GOOGLE_API_KEY`, everything works except the "Autofill from photo"
> button (it just shows a friendly message; you type the fields manually).

Create the tables and load demo data (one senior, "Mr Tan", with a week of
check-ins, medications and reminders):

```powershell
python -m app.seed
```

Run the API:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- Swagger docs: http://localhost:8000/docs
- Health check: http://localhost:8000/healthz
- On Windows you can also double-click **`start_backend.bat`** to launch it.

> **Re-seeding** (`python -m app.seed`) wipes and rebuilds the demo data. The
> demo senior's phone defaults to `6597128022` — change it in
> `app/seed.py` (`phone=...`) if you want a different number.

---

## 5. Flutter caregiver app (`caregiver-app/`)

```powershell
cd caregiver-app
flutter pub get
```

### Create an Android emulator (if you don't have one)

In Android Studio: **Device Manager** (the phone icon) → **Create Virtual
Device** → pick a phone (e.g. Pixel 7) → download a system image (e.g. API 34) →
Finish, then press ▶ on the device to boot it. (Or from the CLI:
`flutter emulators` to list, `flutter emulators --launch <id>` to start one.)

### Run the app

Open `caregiver-app` in Android Studio, select the running emulator (or a
USB-connected phone with developer mode on), and press **Run ▶**. From the CLI:
`flutter run`.

### Pointing the app at the API

The app auto-detects the right host:

| Target                    | API base URL it uses        |
|---------------------------|-----------------------------|
| Android emulator          | `http://10.0.2.2:8000` (loopback to your PC) |
| iOS simulator / desktop   | `http://localhost:8000`     |
| Physical phone (same Wi-Fi)| override — see below       |

For a **physical phone**, find your PC's LAN IP (`ipconfig` / `ifconfig`) and run:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000
```

(Make sure the API is started with `--host 0.0.0.0` and your firewall allows
port 8000.)

### Notes
- The app uses **cleartext HTTP** to the dev backend; this is already allowed
  for `10.0.2.2` / `localhost` / common LAN ranges in
  `android/app/src/main/res/xml/network_security_config.xml`.
- The app uses native plugins (`shared_preferences`, `image_picker`,
  `url_launcher`). After a fresh `flutter pub get`, **fully stop and re-run** the
  app once (Stop ■ → Run ▶) — a hot restart doesn't register native plugins.
  Pure Dart changes only need a hot reload (`r`) / restart (`R`).

You now have a working caregiver app with demo data. The WhatsApp side below is
optional.

---

## 6. WhatsApp companion (`whatsapp-companion/`) — optional

This brings real WhatsApp check-ins, voice transcription, AI replies, and
medication/wellness reminders. Requires Docker Desktop.

### 6.1 Configure
Edit `whatsapp-companion/docker-compose.yml`, in the `backend` service `environment:`

```yaml
- GOOGLE_API_KEY=AIza...your_key...           # from Google AI Studio
- CAREVOICE_DATABASE_URL=postgresql://carevoice:carevoice@host.docker.internal:5432/carevoice
- SELF_TEST_NUMBER=                            # optional, see 6.4
```

`host.docker.internal` lets the container reach PostgreSQL running on your host.

### 6.2 Let the container reach host PostgreSQL
PostgreSQL must accept connections from Docker. Edit these files (path varies by
OS/version, e.g. `C:\Program Files\PostgreSQL\18\data\`):

- **`postgresql.conf`**: `listen_addresses = '*'`
- **`pg_hba.conf`** — add:
  ```
  host  carevoice  carevoice  172.16.0.0/12   scram-sha-256
  host  carevoice  carevoice  192.168.0.0/16  scram-sha-256
  host  carevoice  carevoice  10.0.0.0/8      scram-sha-256
  ```
Then reload: `SELECT pg_reload_conf();` (run as the `postgres` superuser).

### 6.3 Start the stack
```powershell
cd whatsapp-companion
docker compose up -d            # first run builds Whisper (PyTorch) — slow, ~minutes
```
Containers: `evolution-api` (:8080), `carevoice-whisper` (:8001),
`carevoice-backend` (:8002), `evolution-postgres` (internal).

### 6.4 Connect a WhatsApp number
1. Open the Evolution manager: http://localhost:8080/manager (API key
   `supersecretkey123`).
2. Create an instance named **`carevoice`** and **Connect** to show a QR code.
3. Scan the QR from a phone's WhatsApp → **Linked Devices**.
   - ⚠️ This account becomes the **bot** — CareVoice auto-replies to its
     messages. Use a **separate number**, not your primary WhatsApp.
4. Set the instance webhook URL to `http://backend:8000/webhook`
   (event `MESSAGES_UPSERT`).
5. Map a senior to the number people will message *from*:
   ```sql
   UPDATE seniors SET phone='65XXXXXXXX' WHERE id='s_tan';   -- digits, with country code
   ```

**Self-test with one number:** set `SELF_TEST_NUMBER` to your own number
(digits, e.g. `6591234567`) and restart the backend
(`docker compose up -d backend`). Then link your own WhatsApp and use the
"Message Yourself" chat — CareVoice records your messages without auto-replying
to anyone else.

---

## 7. Daily startup order

1. PostgreSQL (auto-starts as a service on most installs).
2. CareVoice API: `uvicorn app.main:app --host 0.0.0.0 --port 8000` (or `start_backend.bat`).
3. Flutter app: Run from Android Studio.
4. (Optional) WhatsApp companion: `docker compose up -d` in `whatsapp-companion`.

---

## 8. Testing without WhatsApp

You can exercise the full check-in → app pipeline without a phone.

- **Desktop tester** (Windows): double-click `whatsapp-companion/send_checkin.ps1`,
  press Enter (defaults to the demo senior), and type what the senior "said".
- **Or curl** the WhatsApp backend's simulate endpoint:
  ```bash
  curl -X POST http://localhost:8002/checkin \
       -H "Content-Type: application/json" \
       -d '{"phone":"6597128022","text":"I feel very giddy and weak today"}'
  ```
The check-in appears in the app within ~15s (it auto-refreshes).

---

## Verify your setup

Tick these off — if all pass, you're fully set up:

- [ ] `psql -U carevoice -d carevoice -c "select 1"` connects.
- [ ] `http://localhost:8000/healthz` returns `{"status":"ok"}`.
- [ ] `http://localhost:8000/api/seniors` returns at least the demo senior (Mr Tan).
- [ ] The emulator app loads the **Home** tab and shows the senior card.
- [ ] **Trends** shows a mood chart + check-in history; **Community** shows events.
- [ ] (OCR) Add-medicine → pick a photo → **Autofill from photo** fills fields
      (needs `GOOGLE_API_KEY` in `carevoice-api/.env`).
- [ ] (WhatsApp, optional) `http://localhost:8080/` responds; instance state is
      `open`; a `POST /checkin` (or a real WhatsApp message) shows up in the app.

---

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| App: "Can't reach the CareVoice server" | API not running, or wrong base URL. Start it with `--host 0.0.0.0`; on a physical phone use `--dart-define=API_BASE_URL=http://<PC-LAN-IP>:8000`. |
| `MissingPluginException` / `channel-error` (shared_preferences, image_picker, url_launcher) | Fully **stop and re-run** the app (hot restart doesn't register native plugins). |
| OCR / AI says "AI is busy (rate limit)" or 429 | Free-tier Gemini quota hit. Use **your own** `GOOGLE_API_KEY` (in `carevoice-api/.env` and `whatsapp-companion/docker-compose.yml`); it resets daily. The app falls back gracefully (manual entry / templated replies / keyword analysis). |
| `image_picker` "already_active" | Handled with a guard + lost-data recovery; if the emulator camera is flaky, use **Gallery** instead. |
| Evolution API stuck "Restarting" | Its database container died — `docker ps`; if `evolution-postgres` is down run `docker compose up -d`. WhatsApp may need a QR re-scan if the session logged out. |
| Docker backend `carevoice_db: false` at `/health` | PostgreSQL not reachable from Docker — check section 6.2 (`listen_addresses`, `pg_hba.conf`). |
| Port 5432 conflict when starting Docker | The bundled `evolution-postgres` has **no** host port mapping by design; your native PostgreSQL keeps 5432. |
| WhatsApp reply loops / replies to everyone | Don't link your primary number; use a separate number or `SELF_TEST_NUMBER`. |
| Voice memo not transcribed | Whisper container still downloading its model on first boot — check `docker logs carevoice-whisper`. |

---

## 10. Handy configuration knobs

| What | Where |
|---|---|
| Database connection | `carevoice-api/.env` → `DATABASE_URL` |
| Gemini key for OCR | `carevoice-api/.env` → `GOOGLE_API_KEY` |
| Gemini key for WhatsApp AI | `whatsapp-companion/docker-compose.yml` → `GOOGLE_API_KEY` |
| Demo senior(s) shown | `carevoice-api/app/seed.py` → `KEEP_SENIOR_IDS` (set to `None` for all) |
| Demo senior's phone | `carevoice-api/app/seed.py` → `phone=...` (default `6597128022`) |
| Community events source | `carevoice-api/app/routers/events.py` (`_SOURCE_URL` + `_FALLBACK`) |
| App API URL override | `flutter run --dart-define=API_BASE_URL=...` |
| Whisper model (multilingual) | `whatsapp-companion/docker-compose.yml` → `WHISPER_MODEL` (tiny/base/small/medium/large-v3/**turbo**) |
| Reminder timing (10 min / 30 min / max) | `whatsapp-companion/backend/app/carevoice_db.py` → `NO_ANSWER_MINUTES`, `LATER_MINUTES`, `due_reminders(max_followups=…)` |
| Self-test number | `whatsapp-companion/docker-compose.yml` → `SELF_TEST_NUMBER` |
| Reminder poll wording | `whatsapp-companion/backend/app/main.py` → `POLL_TAKEN`, `POLL_LATER`, `_reminder_text` |

> **Fresh installs vs this dev machine:** `python -m app.seed` runs
> `drop_all` + `create_all`, so it builds the **complete current schema** from
> `app/models.py` automatically — no manual migrations needed on a new machine.
> (During development the live DB was migrated with `ALTER TABLE`; new installs
> skip that.)
