# SeniorCare

WhatsApp-based AI voice companion for seniors living alone.

## Features

- 🎤 Voice messages → AI responds naturally
- 💊 Medication reminders
- ❤️ Daily wellness check-ins
- 🚨 SOS emergency alerts ("help me")
- 📱 Caregiver dashboard (Flutter app)

## Tech Stack

- **Backend**: FastAPI (Python)
- **AI**: Google Gemini (FREE)
- **Speech-to-Text**: OpenAI Whisper
- **Database**: PostgreSQL
- **WhatsApp**: Evolution API
- **Frontend**: Flutter

## How to Run

### Prerequisites

- Docker Desktop installed
- Python 3.9+ (for Whisper service)
- Google AI Studio API key (FREE)

### Step 1: Get API Key

1. Go to https://aistudio.google.com
2. Sign in with Google account
3. Click "Get API key" → "Create API key"
4. Copy the key

### Step 2: Start Whisper Service (Run on Windows)

Open a **separate PowerShell window**:

```bash
cd C:\Users\yourname\seniorcare

# Install Whisper dependencies
pip install -r requirements_whisper.txt

# Start Whisper service
python whisper_service.py
```

Wait for: `"Whisper model loaded!"`

The service runs at: `http://localhost:8001`

**Note:** First time will download Whisper model (~260MB). Subsequent runs load from cache.

### Step 3: Add API Key to docker-compose.yml

Open `docker-compose.yml` and add to `backend.environment`:

```yaml
- GOOGLE_API_KEY=AIzaSy...your_api_key_here
```

### Step 4: Start Docker Services

```bash
docker compose up -d
```

### Step 5: Test

Send a WhatsApp message to your SeniorCare number:

- "Hello" → Bot greets you
- "taken" → Bot confirms medication
- "help me" → Bot alerts caregiver

## Project Structure
seniorcare/
├── backend/
│ ├── app/
│ │ └── main.py
│ ├── requirements.txt
│ └── Dockerfile
├── whisper_service.py
├── requirements_whisper.txt
├── docker-compose.yml
└── README.md
## Troubleshooting

**Whisper not working?**
```bash
python whisper_service.py
```

**Backend not responding?**
```bash
docker compose restart backend
```

**Check logs:**
```bash
docker compose logs backend
```
