# Backup-Postman.ps1
param(
    [Parameter(Mandatory)]
    [string]$ApiKey,

    [string]$Output = "$PWD\PostmanBackup"
)

$headers = @{ "X-Api-Key" = $ApiKey }

$collectionsDir = Join-Path $Output "Collections"
$envDir         = Join-Path $Output "Environments"

New-Item -ItemType Directory -Force -Path $collectionsDir, $envDir | Out-Null

function SafeName($name) {
    return ($name -replace '[\\/:*?"<>|]', '_')
}

Write-Host "Backing up collections..."
$collections = Invoke-RestMethod `
    -Uri "https://api.getpostman.com/collections" `
    -Headers $headers

foreach ($c in $collections.collections) {
    $name = SafeName $c.name
    $uid  = $c.uid

    Write-Host "  Collection: $name"

    $data = Invoke-RestMethod `
        -Uri "https://api.getpostman.com/collections/$uid" `
        -Headers $headers

    $file = Join-Path $collectionsDir "$name.json"
    $data | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $file
}

Write-Host "Backing up environments..."
$envs = Invoke-RestMethod `
    -Uri "https://api.getpostman.com/environments" `
    -Headers $headers

foreach ($e in $envs.environments) {
    $name = SafeName $e.name
    $uid  = $e.uid

    Write-Host "  Environment: $name"

    $data = Invoke-RestMethod `
        -Uri "https://api.getpostman.com/environments/$uid" `
        -Headers $headers

    $file = Join-Path $envDir "$name.json"
    $data | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 $file
}

Write-Host ""
Write-Host "Backup complete: $Output"