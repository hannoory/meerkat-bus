# ghost-procscan.ps1 — 프로세스 전수 조사
# 전체 프로세스를 커맨드라인 포함해서 덤프한다(Get-Process보다 Win32_Process가
# CommandLine을 더 잘 줌). 의심 키워드(git/checkout/reset/restore/sync/backup/
# vault/meerkat/claude/robocopy/rclone/vscode 등) 있는 줄은 위쪽에 따로 뽑아준다.

$out = "C:\tmp\procscan.txt"
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("=== 잰 시각: $(Get-Date -Format o) ===")
[void]$sb.AppendLine("")

try {
  $procs = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine
} catch {
  [void]$sb.AppendLine("Get-CimInstance 실패: $($_.Exception.Message) — Get-Process로 대체")
  $procs = Get-Process | Select-Object Id, ProcessName, StartTime, Path | ForEach-Object {
    [PSCustomObject]@{
      ProcessId = $_.Id; ParentProcessId = $null; Name = $_.ProcessName
      CreationDate = $_.StartTime; CommandLine = $_.Path
    }
  }
}

$keywords = 'git|checkout|reset|restore|revert|sync|backup|vault|meerkat|claude|robocopy|rclone|onedrive|xcopy|rsync|mirror|snapshot|shadow|vss'

[void]$sb.AppendLine("--- ① 의심 키워드 매치(이름 또는 커맨드라인) ---")
$suspects = $procs | Where-Object {
  ($_.Name -match $keywords) -or ($_.CommandLine -match $keywords)
}
if ($suspects) {
  foreach ($p in $suspects) {
    [void]$sb.AppendLine("PID=$($p.ProcessId) PPID=$($p.ParentProcessId) 시작=$($p.CreationDate) 이름=$($p.Name)")
    [void]$sb.AppendLine("  CMD: $($p.CommandLine)")
  }
} else {
  [void]$sb.AppendLine("(매치 없음)")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- ② 전체 프로세스(이름순) ---")
$procs | Sort-Object Name | ForEach-Object {
  [void]$sb.AppendLine("PID=$($_.ProcessId) PPID=$($_.ParentProcessId) 시작=$($_.CreationDate) 이름=$($_.Name)")
  if ($_.CommandLine) { [void]$sb.AppendLine("  CMD: $($_.CommandLine)") }
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- ③ 예약작업 중 '준비/실행중'인 것만(다음 실행시각 포함) ---")
try {
  Get-ScheduledTask | Where-Object { $_.State -eq 'Running' } | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo
    [void]$sb.AppendLine("작업명=$($_.TaskName) 경로=$($_.TaskPath) 상태=$($_.State) 마지막실행=$($info.LastRunTime) 다음실행=$($info.NextRunTime)")
  }
} catch {
  [void]$sb.AppendLine("예약작업 조회 실패: $($_.Exception.Message)")
}

$sb.ToString() | Out-File -FilePath $out -Encoding utf8 -Force
Write-Host "결과 저장: $out (총 $($procs.Count)개 프로세스)"
Write-Host "의심 매치: $($suspects.Count)건"
