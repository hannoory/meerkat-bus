# ghost-diag.ps1 - .omc/ 유령 재발사 버그 진단 (읽기 전용, 안전. 삭제/수정 없음)
# 실행: 이 파일을 .omc 밖(바탕화면 등)에 저장하고 pwsh -File ghost-diag.ps1
$ErrorActionPreference = 'SilentlyContinue'
$omc = "C:\Claude\meerkat-committee\.omc"
$out = "$env:USERPROFILE\Desktop\ghost-diag-out.txt"
"=== 진단 시작 $(Get-Date -Format o) ===" | Out-File -FilePath $out

"`n--- [1] .omc 폴더 자체가 심볼릭링크/정션인가? ---" | Out-File -FilePath $out -Append
Get-Item -Force $omc | Select-Object FullName, LinkType, Target | Format-List | Out-String | Out-File -FilePath $out -Append

"`n--- [2] C:\Claude 가 OneDrive 등 클라우드 동기화 아래 있는가? ---" | Out-File -FilePath $out -Append
$attrs = (Get-Item -Force "C:\Claude").Attributes
"C:\Claude Attributes: $attrs" | Out-File -FilePath $out -Append
Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" | Out-String | Out-File -FilePath $out -Append
Get-Process OneDrive | Select-Object Id, Path | Format-Table | Out-String | Out-File -FilePath $out -Append

"`n--- [3] 관련 예약 작업(스케줄러) ---" | Out-File -FilePath $out -Append
Get-ScheduledTask | Where-Object {
    $_.TaskName -match 'vault|backup|restore|sync|meerkat|claude|omc|mirror'
} | Select-Object TaskName, State, @{n='Actions'; e={($_.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join ' | '}} |
Format-List | Out-String | Out-File -FilePath $out -Append

"`n--- [4] vault-push 정의를 harness 스크립트에서 찾기 ---" | Out-File -FilePath $out -Append
Get-ChildItem "C:\Claude\meerkat-committee\docs\harness" -Recurse -Include *.ps1, *.sh |
    Select-String -Pattern 'vault-push' -List |
    ForEach-Object { "`n>>> $($_.Path)"; Get-Content $_.Path } |
    Out-File -FilePath $out -Append
Get-ChildItem $omc -Filter '*vault*' -File | Select-Object Name, Length, LastWriteTime | Format-Table | Out-String | Out-File -FilePath $out -Append

"`n--- [5] Windows Defender 제어된 폴더 접근(자동 복원 기능 있음) ---" | Out-File -FilePath $out -Append
Get-MpPreference | Select-Object EnableControlledFolderAccess, ControlledFolderAccessProtectedFolders, ControlledFolderAccessAllowedApplications |
    Format-List | Out-String | Out-File -FilePath $out -Append

"`n--- [6] 지금 이 순간 백업/동기화/복사 관련 프로세스 ---" | Out-File -FilePath $out -Append
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -match 'vault|backup|restore|robocopy|rsync|OneDrive|sync|mirror'
} | Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine |
Format-List | Out-String | Out-File -FilePath $out -Append

"`n--- [7] next.md / eungyeol-batch.txt 실시간 변경 10분 감시 (백그라운드) ---" | Out-File -FilePath $out -Append
$watchLog = "$env:USERPROFILE\Desktop\ghost-watch-log.txt"
"감시 시작 $(Get-Date -Format o)" | Out-File -FilePath $watchLog
Start-Job -ScriptBlock {
    param($omcPath, $logPath)
    $fsw = New-Object System.IO.FileSystemWatcher $omcPath
    $fsw.Filter = '*'
    $fsw.IncludeSubdirectories = $false
    $end = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $end) {
        $result = $fsw.WaitForChanged(([System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Created), 5000)
        if (-not $result.TimedOut -and ($result.Name -eq 'next.md' -or $result.Name -eq 'eungyeol-batch.txt')) {
            $ts = Get-Date -Format o
            $procs = (Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'omc|vault|meerkat|claude' } | ForEach-Object { "$($_.ProcessId):$($_.Name)" }) -join ', '
            "$ts  $($result.ChangeType) $($result.Name)  |  동시 프로세스: $procs" | Add-Content $logPath
        }
    }
} -ArgumentList $omc, $watchLog | Out-Null
"백그라운드 감시 시작됨 - 10분간 $watchLog 에 기록. 이 창 닫아도 계속 돔." | Out-File -FilePath $out -Append

"`n=== 진단 끝. 결과: $out (그리고 10분 뒤 $watchLog) ===" | Out-File -FilePath $out -Append
notepad $out
