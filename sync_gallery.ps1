param(
    [string]$SourceVideos = 'C:\Users\Jacob\Pictures\Blender\Projects\VISUAL SYNTH\renders\Videos'
)

$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot
$DistDir = Join-Path $ProjectDir 'dist'
$MediaDir = Join-Path $DistDir 'media'
$PosterDir = Join-Path $DistDir 'posters'
$FavoritesFile = Join-Path $ProjectDir 'favorites.txt'
$Ffmpeg = 'C:\Users\Jacob\Pictures\Blender\Projects\VISUAL SYNTH\Tools\FFmpeg\ffmpeg.exe'
$EncodingVersion = 'visual-synth-web-video-v2-960p-crf30'
$EncodingStamp = Join-Path $MediaDir '.encoding-version'

if (-not (Test-Path -LiteralPath $Ffmpeg)) {
    throw "FFmpeg was not found at $Ffmpeg"
}

New-Item -ItemType Directory -Path $MediaDir, $PosterDir -Force | Out-Null
$ForceVideoRebuild = -not (Test-Path -LiteralPath $EncodingStamp) -or
    ((Get-Content -LiteralPath $EncodingStamp -Raw).Trim() -ne $EncodingVersion)

$requested = Get-Content -LiteralPath $FavoritesFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

$usedIds = @{}
$items = @()
$number = 0

foreach ($name in $requested) {
    $source = Join-Path $SourceVideos $name
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Warning "Skipped missing video: $name"
        continue
    }

    $number++
    $baseId = [IO.Path]::GetFileNameWithoutExtension($name).ToLowerInvariant()
    $baseId = [regex]::Replace($baseId, '[^a-z0-9]+', '-').Trim('-')
    if (-not $baseId) { $baseId = "piece-$number" }
    $id = $baseId
    $suffix = 2
    while ($usedIds.ContainsKey($id)) {
        $id = "$baseId-$suffix"
        $suffix++
    }
    $usedIds[$id] = $true

    $videoName = "$id.mp4"
    $posterName = "$id.webp"
    $videoOut = Join-Path $MediaDir $videoName
    $posterOut = Join-Path $PosterDir $posterName
    $sourceInfo = Get-Item -LiteralPath $source

    if ($ForceVideoRebuild -or -not (Test-Path -LiteralPath $videoOut) -or (Get-Item -LiteralPath $videoOut).LastWriteTimeUtc -lt $sourceInfo.LastWriteTimeUtc) {
        Write-Host "[$number/$($requested.Count)] Optimizing $name"
        & $Ffmpeg -y -hide_banner -loglevel error -i $source -an `
            -vf 'fps=30,scale=w=960:h=960:force_original_aspect_ratio=decrease:force_divisible_by=2' `
            -c:v libx264 -preset fast -crf 30 -pix_fmt yuv420p `
            -g 60 -keyint_min 60 -sc_threshold 0 -movflags +faststart $videoOut
        if ($LASTEXITCODE -ne 0) { throw "Video optimization failed for $name" }
    }

    if (-not (Test-Path -LiteralPath $posterOut) -or (Get-Item -LiteralPath $posterOut).LastWriteTimeUtc -lt $sourceInfo.LastWriteTimeUtc) {
        & $Ffmpeg -y -hide_banner -loglevel error -ss 0.1 -i $source -frames:v 1 `
            -vf 'scale=w=640:h=640:force_original_aspect_ratio=increase,crop=640:640' `
            -c:v libwebp -quality 78 $posterOut
        if ($LASTEXITCODE -ne 0) { throw "Poster creation failed for $name" }
    }

    $title = [IO.Path]::GetFileNameWithoutExtension($name) -replace '[_-]+', ' '
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLowerInvariant())
    $title = $title -replace '\bGpt\b', 'GPT' -replace '\bY2k\b', 'Y2K'
    $items += [ordered]@{
        id = $id
        title = $title
        video = "media/$videoName"
        poster = "posters/$posterName"
    }
}

$json = ConvertTo-Json -InputObject @($items) -Depth 4 -Compress
$data = "window.GALLERY_ITEMS = $json;`n"
[IO.File]::WriteAllText((Join-Path $DistDir 'gallery-data.js'), $data, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($EncodingStamp, "$EncodingVersion`n", [Text.UTF8Encoding]::new($false))

$wantedVideoNames = $items.video | ForEach-Object { [IO.Path]::GetFileName($_) }
$wantedPosterNames = $items.poster | ForEach-Object { [IO.Path]::GetFileName($_) }
Get-ChildItem -LiteralPath $MediaDir -File -Filter *.mp4 | Where-Object Name -NotIn $wantedVideoNames | Remove-Item -Force
Get-ChildItem -LiteralPath $PosterDir -File | Where-Object Name -NotIn $wantedPosterNames | Remove-Item -Force

$totalMb = [math]::Round(((Get-ChildItem -LiteralPath $MediaDir -File | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host "Gallery ready: $($items.Count) pieces, $totalMb MB of web video."
