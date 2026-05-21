from fastapi import FastAPI
from pydantic import BaseModel
import whisper
import base64
import os
import uvicorn


app = FastAPI(title="Whisper Speech-to-Text Service")

# Load Whisper model on startup (uses GPU if available)
print("Loading Whisper model...")
model = whisper.load_model("small")  # Options: "tiny", "base", "small", "medium", "large"
print("Whisper model loaded!")

class TranscribeRequest(BaseModel):
    file_path: str | None = None
    base64_audio: str | None = None

@app.get("/")
async def root():
    return {"message": "Whisper Speech-to-Text Service is running"}

@app.get("/health")
async def health():
    return {"status": "healthy", "model": "whisper-small"}

@app.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    """Transcribe audio file from file path"""
    if not request.file_path or not os.path.exists(request.file_path):
        return {"error": "File not found"}

    print(f"Transcribing: {request.file_path}")
    result = model.transcribe(request.file_path)
    return {
        "text": result.get("text", ""),
        "language": result.get("language", "unknown"),
        "duration": result.get("duration", 0)
    }

@app.post("/transcribe_base64")
async def transcribe_base64(request: TranscribeRequest):
    """Transcribe audio from base64 encoded bytes"""
    if not request.base64_audio:
        return {"error": "No audio data provided"}

    # Decode base64 to bytes
    audio_bytes = base64.b64decode(request.base64_audio)

    # Save to temp file
    temp_file = "temp_audio.ogg"
    with open(temp_file, "wb") as f:
        f.write(audio_bytes)

    print("Transcribing audio...")
    result = model.transcribe(temp_file)

    # Cleanup
    os.remove(temp_file)

    return {
        "text": result.get("text", ""),
        "language": result.get("language", "unknown"),
        "duration": result.get("duration", 0)
    }

@app.post("/transcribe_bytes")
async def transcribe_bytes(request: TranscribeRequest):
    """Transcribe audio from raw bytes (for API calls)"""
    if not request.base64_audio:
        return {"error": "No audio data provided"}

    audio_bytes = base64.b64decode(request.base64_audio)
    temp_file = "temp_audio.ogg"

    with open(temp_file, "wb") as f:
        f.write(audio_bytes)

    print("Transcribing audio with Whisper...")
    result = model.transcribe(temp_file)
    os.remove(temp_file)

    # Debug: print the result keys
    print(f"Whisper result keys: {result.keys()}")

    return {
        "text": result.get("text", ""),
        "language": result.get("language", "unknown"),
        "duration": result.get("duration", 0),
        "segments": result.get("segments", [])
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)