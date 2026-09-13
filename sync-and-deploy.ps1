<#
.SYNOPSIS
    제텔카스텐 Obsidian 볼트의 내용을 Quartz content 폴더로 동기화하고 GitHub에 푸시하여 GitHub Pages로 배포합니다.
#>

param(
    [string]$CommitMessage = "content: sync from vault $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

$ErrorActionPreference = "Stop"

$vaultPath = "G:\내 드라이브\Obsidian\제텔카스텐"
$quartzPath = "G:\내 드라이브\Obsidian\zettelkasten-quartz"
$contentPath = Join-Path $quartzPath "content"

Write-Host "=== 1. 볼트 파일 동기화 시작 ===" -ForegroundColor Cyan

# 1. 디렉토리 동기화 (노트, Reference, 일간노트, 첨부파일)
$syncDirs = @("노트", "Reference", "일간노트", "첨부파일")
foreach ($dir in $syncDirs) {
    $src = Join-Path $vaultPath $dir
    $dst = Join-Path $contentPath $dir
    if (Test-Path $src) {
        Write-Host "  -> 동기화 중: $dir"
        robocopy $src $dst /E /PURGE /NDL /NFL /NJH /NJS /nc /ns /np | Out-Null
    }
}

# 2. 루트 파일 동기화 (.md, .canvas) - 숨김 및 설정 파일 제외
Get-ChildItem -Path $vaultPath -File | Where-Object {
    $_.Extension -in @(".md", ".canvas") -and 
    $_.Name -notmatch "^\." -and 
    $_.Name -notmatch "^(package|package-lock)"
} | ForEach-Object {
    Copy-Item $_.FullName -Destination $contentPath -Force
}

# 3. HOME.md -> index.md (Quartz 홈페이지)
if (Test-Path "$vaultPath\HOME.md") {
    Copy-Item "$vaultPath\HOME.md" -Destination "$contentPath\index.md" -Force
    Write-Host "  -> HOME.md를 index.md로 갱신 완료"
}

Write-Host "=== 2. Git 상태 확인 및 커밋 ===" -ForegroundColor Cyan
Set-Location $quartzPath

git add .
$status = git status --porcelain

if (-not $status) {
    Write-Host "변경 사항이 없습니다." -ForegroundColor Yellow
} else {
    Write-Host "변경 사항 커밋 중: $CommitMessage"
    git commit -m $CommitMessage

    $currentBranch = (git branch --show-current).Trim()
    Write-Host "=== 3. GitHub 푸시 (브랜치: $currentBranch) ===" -ForegroundColor Cyan
    git push origin $currentBranch
    Write-Host "푸시 완료! GitHub Actions에서 자동으로 GitHub Pages 배포가 진행됩니다." -ForegroundColor Green
}
