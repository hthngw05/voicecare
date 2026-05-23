# CareVoice check-in tester
# Simulates an elderly person's WhatsApp message: runs the SAME analysis +
# database pipeline a real WhatsApp message triggers, then writes it to the
# CareVoice database so it appears in the Flutter caregiver app.
#
# Requires the voicecare backend container to be running:
#     docker compose up -d backend
#
# Pick a phone to attach the check-in to a seeded senior, or type any number
# to auto-create a new senior.

$base = "http://localhost:8002"

Write-Host ""
Write-Host "  CareVoice check-in tester" -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------"
Write-Host "  Active senior:"
Write-Host "    6597128022  Mr Tan Boon Huat  (Mandarin/Singlish)  <- default"
Write-Host "  Just press Enter to send as Mr Tan."
Write-Host "  (Type any other number to auto-create a new senior.)"
Write-Host "  ------------------------------------------------------------"
Write-Host "  Try: 'I'm feeling good today, took my medicine'  (info)"
Write-Host "       'Very sian today, cannot sleep'             (concern)"
Write-Host "       'I feel very giddy and weak'                (concern)"
Write-Host "       'Help me, I fell down and cannot get up'    (emergency)"
Write-Host ""

# Quick reachability check.
try {
    $h = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 3
    Write-Host ("  Backend OK (carevoice_db={0})" -f $h.carevoice_db) -ForegroundColor Green
} catch {
    Write-Host "  Cannot reach backend at $base" -ForegroundColor Red
    Write-Host "  Start it with:  docker compose up -d backend" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    return
}
Write-Host ""

while ($true) {
    $phone = Read-Host "Phone (Enter = 6597128022 Mr Tan, q = quit)"
    if ($phone -eq 'q') { break }
    if ([string]::IsNullOrWhiteSpace($phone)) { $phone = "6597128022" }

    $text = Read-Host "What did the senior say?"
    if ([string]::IsNullOrWhiteSpace($text)) { continue }

    $body = @{ phone = $phone; text = $text } | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Uri "$base/checkin" -Method Post -ContentType "application/json" -Body $body
        $res = $r.result
        $color = switch ($res.alert_level) {
            "emergency" { "Red" }
            "urgent"    { "Red" }
            "concern"   { "Yellow" }
            default     { "Green" }
        }
        Write-Host ""
        Write-Host ("  -> {0}" -f $res.senior_name) -ForegroundColor $color
        Write-Host ("     level     : {0}" -f $res.alert_level) -ForegroundColor $color
        Write-Host ("     sentiment : {0}" -f $res.sentiment_score)
        Write-Host ("     flags     : {0}" -f ($res.risk_flags -join ', '))
        Write-Host ("     summary   : {0}" -f $res.summary)
        Write-Host "     (pull-to-refresh the Flutter app to see it)" -ForegroundColor DarkGray
        Write-Host ""
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
}
