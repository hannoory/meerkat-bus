# ghost-watch2.ps1 - .omc 변경 감시 (창을 닫아도 안 죽게 완전히 분리해서 돔)
# 지난 판은 Start-Job(부모 콘솔에 묶임)이라 창을 닫자마자 죽어서 시작줄 하나만 남았음.
# 이번 판은 Start-Process 로 완전히 딴 프로세스를 띄워서 이 창을 닫아도 계속 돈다.
$ErrorActionPreference = 'SilentlyContinue'
$inner = @'
$omc = "C:\Claude\meerkat-committee\.omc"
$logPath = "$env:USERPROFILE\Desktop\ghost-watch-log2.txt"
"감시 시작(분리 프로세스) $(Get-Date -Format o)" | Out-File -FilePath $logPath -Encoding UTF8
$fsw = New-Object System.IO.FileSystemWatcher $omc
$fsw.Filter = '*'
$fsw.IncludeSubdirectories = $false
$end = (Get-Date).AddMinutes(15)
while ((Get-Date) -lt $end) {
    $result = $fsw.WaitForChanged(([System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Created -bor [System.IO.WatcherChangeTypes]::Renamed), 5000)
    if (-not $result.TimedOut -and ($result.Name -eq 'next.md' -or $result.Name -eq 'eungyeol-batch.txt')) {
        $ts = Get-Date -Format o
        $procs = (Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'omc|vault|meerkat|claude|bus|kipina' } | ForEach-Object { "$($_.ProcessId):$($_.Name):$($_.CreationDate)" }) -join ' | '
        "$ts  $($result.ChangeType) $($result.Name)  동시프로세스: $procs" | Out-File -FilePath $logPath -Encoding UTF8 -Append
    }
}
"감시 끝 $(Get-Date -Format o)" | Out-File -FilePath $logPath -Encoding UTF8 -Append
'@
$innerFile = "$env:TEMP\ghost-watch-inner.ps1"
[System.IO.File]::WriteAllText($innerFile, $inner, (New-Object System.Text.UTF8Encoding($false)))
Start-Process powershell.exe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $innerFile) -WindowStyle Hidden
"분리된 감시 프로세스 시작함 - 15분간 $env:USERPROFILE\Desktop\ghost-watch-log2.txt 에 기록됨." | Write-Host
"이 창(또는 pwsh)을 닫아도 계속 돈다. 15분 뒤에 그 파일을 열어봐줘." | Write-Host
