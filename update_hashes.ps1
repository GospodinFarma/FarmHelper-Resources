# Запускать из PowerShell: .\update_hashes.ps1
# Скрипт пересчитывает SHA-256 для всех PNG, найденных в aks/, и обновляет manifest.json.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $root 'manifest.json'
$aksDir = Join-Path $root 'aks'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Не найден manifest.json: $manifestPath"
}
if (-not (Test-Path -LiteralPath $aksDir)) {
    throw "Не найдена папка aks: $aksDir"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $manifest.images) {
    throw 'В manifest.json отсутствует объект images.'
}

$updated = 0
$missing = 0
foreach ($property in $manifest.images.PSObject.Properties) {
    $id = $property.Name
    $entry = $property.Value
    $file = [string]$entry.file
    if ([string]::IsNullOrWhiteSpace($file) -or $file -notmatch '^[A-Za-z0-9_-]+\.png$') {
        Write-Warning "Пропускаю некорректное имя файла для $id"
        continue
    }

    $path = Join-Path $aksDir $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Warning "Нет файла: aks/$file"
        $missing++
        continue
    }

    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $entry.sha256 = $hash
    Write-Host "OK  $id -> $file"
    $updated++
}

# Обновляем patch-версию, чтобы изменение manifest было заметно в истории репозитория.
$versionText = [string]$manifest.version
if ($versionText -match '^(\d+)\.(\d+)\.(\d+)$') {
    $manifest.version = "$($Matches[1]).$($Matches[2]).$([int]$Matches[3] + 1)"
}

$json = $manifest | ConvertTo-Json -Depth 20
$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", $utf8NoBom)

Write-Host ""
Write-Host "Обновлено SHA-256: $updated"
Write-Host "Отсутствует PNG: $missing"
Write-Host "Новая версия manifest: $($manifest.version)"
Write-Host 'Теперь загрузите обновлённый manifest.json в GitHub.'
