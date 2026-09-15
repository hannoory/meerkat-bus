# ghost-watch3.ps1
# ghost-watch2.ps1이 로그 파일을 전혀 안 남긴 원인을 잡기 위한 진단판.
# - 시작하자마자 "마커" 파일을 바탕화면에 즉시 씀(부모 프로세스에서, 동기적으로)
#   → 이거 하나만 봐도 스크립트가 "실행은 됐는지" 1~2초 안에 알 수 있음.
# - 분리(detached) 감시 프로세스가 실패하면 에러를 파일로 남김(그동안은 그냥
#   조용히 죽어서 아무 단서가 없었음).
# - 감시 로그는 15분간 .omc 폴더의 파일 변경(Changed/Created/Renamed)을 기록.

$desktop = [Environment]::GetFolderPath('Desktop')
$startMarker = Join-Path $desktop 'ghost-watch3-started.txt'
$logFile     = Join-Path $desktop 'ghost-watch-log3.txt'
$errFile     = Join-Path $desktop 'ghost-watch3-error.txt'
$innerScript = Join-Path $env:TEMP 'ghost-watch3-inner.ps1'

"시작 시각: $(Get-Date -Format o)" | Out-File -FilePath $startMarker -Encoding utf8

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
} catch {
  $_ | Out-String | Out-File -FilePath $errFile -Encoding utf8
  "detach 실행 실패 — $errFile 확인" | Add-Content -Path $startMarker -Encoding utf8
}

Write-Host "시작 마커(바로 생김): $startMarker"
Write-Host "감시 로그(15분 후): $logFile"
Write-Host "에러(실패시만): $errFile"
