# ghost-watch4.ps1
# 바탕화면 경로(OneDrive 리다이렉션 등으로 꼬였을 수 있음) 대신
# 스크립트와 같은 폴더(C:\tmp)에 전부 쓴다 — 위치를 확실히 하기 위함.
# 창이 바로 안 닫히게 마지막에 멈춰서 기다린다.

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = 'C:\tmp' }

$startMarker = Join-Path $outDir 'gw4-started.txt'
$logFile     = Join-Path $outDir 'gw4-log.txt'
$errFile     = Join-Path $outDir 'gw4-error.txt'
$innerScript = Join-Path $env:TEMP 'gw4-inner.ps1'

Write-Host "출력 폴더: $outDir"
Write-Host "마커 파일 경로: $startMarker"

try {
  "시작 시각: $(Get-Date -Format o)" | Out-File -FilePath $startMarker -Encoding utf8 -Force
  Write-Host "마커 파일 쓰기 성공"
} catch {
  Write-Host "마커 파일 쓰기 실패: $($_.Exception.Message)"
}

$innerCode = @'
try {
  $logFile = "__LOGFILE__"
  "감시 시작: $(Get-Date -Format o)" | Out-File -FilePath $logFile -Encoding utf8
  $target = "C:\Claude\meerkat-committee\.omc"
  $watcher = New-Object System.IO.FileSystemWatcher
  $watcher.Path = $target
  $watcher.Filter = "*"
  $watcher.IncludeSubdirectories = $false
  $watcher.EnableRaisingEvents = $true
  $action = {
    $e = $Event.SourceEventArgs
    $line = "$(Get-Date -Format o) | $($e.ChangeType) | $($e.FullPath)"
    Add-Content -Path $using:logFile -Value $line
  }
  $handlers = @()
  $handlers += Register-ObjectEvent $watcher Changed -Action $action
  $handlers += Register-ObjectEvent $watcher Created -Action $action
  $handlers += Register-ObjectEvent $watcher Renamed -Action $action
  Start-Sleep -Seconds 900
  $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
  "감시 종료: $(Get-Date -Format o)" | Out-File -FilePath $logFile -Append -Encoding utf8
} catch {
  $_ | Out-String | Out-File -FilePath "__ERRFILE__" -Encoding utf8
}
'@

$innerCode = $innerCode.Replace('__LOGFILE__', $logFile).Replace('__ERRFILE__', $errFile)
$innerCode | Out-File -FilePath $innerScript -Encoding utf8 -Force

try {
  Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $innerScript) `
    -WindowStyle Hidden
  "detach 실행 성공: $(Get-Date -Format o)" | Add-Content -Path $startMarker -Encoding utf8
  Write-Host "분리 감시 프로세스 실행 성공"
} catch {
  $_ | Out-String | Out-File -FilePath $errFile -Encoding utf8
  Write-Host "분리 감시 프로세스 실행 실패: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "=== 결과 ==="
Write-Host "마커: $startMarker  (있음? $(Test-Path $startMarker))"
Write-Host "로그(15분 후): $logFile"
Write-Host "에러(실패시만): $errFile  (있음? $(Test-Path $errFile))"
Write-Host ""
Write-Host "끝."
