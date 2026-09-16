$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot
$SyncScript = Join-Path $ProjectDir 'sync_gallery.ps1'

try {
    & $SyncScript

    Push-Location $ProjectDir
    try {
        & git add -- favorites.txt dist
        if ($LASTEXITCODE -ne 0) { throw 'Git could not prepare the gallery update.' }

        & git diff --cached --quiet
        $DiffExitCode = $LASTEXITCODE
        if ($DiffExitCode -eq 0) {
            Write-Host ''
            Write-Host 'The live gallery is already up to date.' -ForegroundColor Green
            exit 0
        }
        if ($DiffExitCode -ne 1) { throw 'Git could not check the gallery update.' }

        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        & git commit -m "Update gallery $Timestamp"
        if ($LASTEXITCODE -ne 0) { throw 'Git could not save the gallery update.' }

        & git push origin main
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
