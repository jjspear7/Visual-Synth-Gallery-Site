$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot
$SyncScript = Join-Path $ProjectDir 'sync_gallery.ps1'
$UserProfileDir = [Environment]::GetFolderPath('UserProfile')
if ([string]::IsNullOrWhiteSpace($UserProfileDir)) { $UserProfileDir = $env:USERPROFILE }
if ([string]::IsNullOrWhiteSpace($UserProfileDir) -and $ProjectDir -match '^([A-Za-z]:\\Users\\[^\\]+)') {
    $UserProfileDir = $Matches[1]
}
$BundledGitRoot = Join-Path $UserProfileDir '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git'
$BundledGit = Join-Path $BundledGitRoot 'cmd\git.exe'

if (Test-Path -LiteralPath $BundledGit) {
    $Git = $BundledGit
    $env:GIT_EXEC_PATH = Join-Path $BundledGitRoot 'mingw64\bin'
}
else {
    $GitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $GitCommand) {
        throw 'Git was not found. Open Codex and ask it to repair the gallery publisher.'
    }
    $Git = $GitCommand.Source
}

$SafeDirectory = $ProjectDir.Replace('\', '/')

try {
    & $SyncScript

    Push-Location $ProjectDir
    try {
        & $Git -c "safe.directory=$SafeDirectory" add -- favorites.txt dist
        if ($LASTEXITCODE -ne 0) { throw 'Git could not prepare the gallery update.' }

        & $Git -c "safe.directory=$SafeDirectory" diff --cached --quiet
        $DiffExitCode = $LASTEXITCODE
        if ($DiffExitCode -eq 0) {
            Write-Host ''
            Write-Host 'The live gallery is already up to date.' -ForegroundColor Green
            exit 0
        }
        if ($DiffExitCode -ne 1) { throw 'Git could not check the gallery update.' }

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        & $Git -c "safe.directory=$SafeDirectory" commit -m "Update gallery $Timestamp"
        if ($LASTEXITCODE -ne 0) { throw 'Git could not save the gallery update.' }

        & $Git -c "safe.directory=$SafeDirectory" push origin main
        if ($LASTEXITCODE -ne 0) { throw 'GitHub did not accept the gallery update.' }

        Write-Host ''
        Write-Host 'Published. GitHub Pages will refresh the live gallery in a minute or two.' -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Host ''
    Write-Host "PUBLISH FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Nothing was removed from your original VISUAL SYNTH videos.' -ForegroundColor Yellow
    exit 1
}
