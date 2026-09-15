# ghost-gitcheck.ps1
# 편집기 가설은 빠졌으니, 이번엔 git 쪽 의심 — 어떤 프로세스가 이 파일을
# 주기적으로 "마지막 커밋 상태"로 되돌리고 있는 건 아닌지 확인한다.
# (판단 자리는 git을 직접 못 치니 오빠가 대신 돌려주는 것)

$repo = "C:\Claude\meerkat-committee"
$file = "docs/reports/유령재발사-실측-20260915.md"
$out  = Join-Path $repo ".omc\ghost-gitcheck-out.txt"

Set-Location $repo

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== 잰 시각: $(Get-Date -Format o) ===")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- git log (이 파일, 최근 20개 커밋) ---")
[void]$sb.AppendLine((git --no-optional-locks log --oneline -n 20 -- $file | Out-String))
[void]$sb.AppendLine("--- git status (이 파일만) ---")
[void]$sb.AppendLine((git --no-optional-locks status --porcelain -- $file | Out-String))
[void]$sb.AppendLine("--- git diff HEAD (이 파일, 작업트리 vs 마지막 커밋) — 길면 앞부분만 ---")
$diff = git --no-optional-locks diff HEAD -- $file | Out-String
if ($diff.Length -gt 3000) { $diff = $diff.Substring(0,3000) + "`n...(자름)..." }
[void]$sb.AppendLine($diff)
[void]$sb.AppendLine("--- 이 파일 마지막 커밋 시각 ---")
[void]$sb.AppendLine((git --no-optional-locks log -1 --format="%cI %h %s" -- $file | Out-String))
[void]$sb.AppendLine("--- 디스크상 파일 mtime ---")
$fullPath = Join-Path $repo $file
if (Test-Path $fullPath) {
  [void]$sb.AppendLine((Get-Item $fullPath).LastWriteTime.ToString("o"))
} else {
  [void]$sb.AppendLine("파일 없음!")
}

$sb.ToString() | Out-File -FilePath $out -Encoding utf8 -Force
Write-Host "결과: $out"
Write-Host ""
Write-Host $sb.ToString()
