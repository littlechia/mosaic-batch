param([switch]$NoOpen)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$index = Join-Path $root 'index.html'
if (-not (Test-Path -LiteralPath $index)) {
  Write-Host ''
  Write-Host 'ERROR: index.html not found next to this script.' -ForegroundColor Red
  Write-Host ('        looked in: ' + $root)
  Read-Host 'Press Enter to exit'
  exit 1
}

$py = $null
$pyArgs = @()
$c = Get-Command python -ErrorAction SilentlyContinue
if ($c) { $py = $c.Source }
if (-not $py) {
  $c = Get-Command py -ErrorAction SilentlyContinue
  if ($c) { $py = $c.Source; $pyArgs = @('-3') }
}
if (-not $py) {
  Write-Host ''
  Write-Host 'ERROR: Python not found.' -ForegroundColor Red
  Write-Host 'You can still open index.html directly in Edge, but then it can only download copies.'
  Read-Host 'Press Enter to exit'
  exit 1
}

function Test-Port([int]$p) {
  $cl = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $cl.BeginConnect('127.0.0.1', $p, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne(200)) { return $false }
    $cl.EndConnect($iar)
    return $true
  } catch {
    return $false
  } finally {
    try { $cl.Close() } catch {}
  }
}

$port = 8788
$guard = 0
while ((Test-Port $port) -and ($guard -lt 60)) { $port++; $guard++ }

$allArgs = $pyArgs + @('-m', 'http.server', "$port", '--bind', '127.0.0.1', '-d', $root)
$proc = Start-Process -FilePath $py -ArgumentList $allArgs -WindowStyle Minimized -PassThru

$ok = $false
for ($i = 0; $i -lt 80; $i++) {
  Start-Sleep -Milliseconds 200
  if (Test-Port $port) { $ok = $true; break }
  if ($proc.HasExited) { break }
}

if ($ok) {
  $url = "http://127.0.0.1:$port/"
  if (-not $NoOpen) { Start-Process $url }
  Write-Host ''
  Write-Host ('  URL : ' + $url) -ForegroundColor Green
  Write-Host ('  PID : ' + $proc.Id)
  Write-Host '  Close the minimized python window to stop the server.'
  if (-not $NoOpen) { Start-Sleep -Seconds 3 }
} else {
  Write-Host ''
  Write-Host 'ERROR: local server did not start.' -ForegroundColor Red
  Write-Host ('  python : ' + $py)
  if ($proc.HasExited) { Write-Host ('  exit code : ' + $proc.ExitCode) }
  Read-Host 'Press Enter to exit'
}
