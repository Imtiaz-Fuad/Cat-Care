$bytes = [System.IO.File]::ReadAllBytes('.env')
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
$start = $text.IndexOf('GEMINI_API_KEY=')
if ($start -lt 0) { 'no key line'; exit 1 }
$segment = $text.Substring($start, [Math]::Min(80, $text.Length - $start))
Write-Host "raw line: |$segment|"
$keyStart = $start + 13
$end = $keyStart
while ($end -lt $bytes.Length -and $bytes[$end] -ne 0x0d -and $bytes[$end] -ne 0x0a) { $end++ }
$keyBytes = $bytes[$keyStart..($end - 1)]
$key = [System.Text.Encoding]::UTF8.GetString($keyBytes)
Write-Host "key value: |$key|"
Write-Host "key length: $($key.Length)"
Write-Host "key bytes:"
foreach ($b in $keyBytes) { Write-Host -NoNewline ("{0:x2} " -f $b) }
Write-Host ""
Write-Host "starts with AIzaSy: $($key.StartsWith('AIzaSy'))"
Write-Host ""
Write-Host "--- probing GET https://generativelanguage.googleapis.com/v1/models"
try {
    $r = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "https://generativelanguage.googleapis.com/v1/models?key=$key" -ErrorAction Stop
    Write-Host "status: $($r.StatusCode)"
    Write-Host "body (first 800):"
    Write-Host ($r.Content.Substring(0, [Math]::Min(800, $r.Content.Length)))
} catch {
    Write-Host "ERR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "body:"
        Write-Host $sr.ReadToEnd()
    }
}
