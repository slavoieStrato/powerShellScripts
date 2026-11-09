<#
.SYNOPSIS
    Removes USB controller devices and optionally rescans Plug-and-Play devices.

.EXAMPLES
    .\remove_usb_controllers.ps1
    .\remove_usb_controllers.ps1 -Rescan
    .\remove_usb_controllers.ps1 -All
    .\remove_usb_controllers.ps1 -All -Pattern "USB Root Hub*" -Force -Rescan
    .\remove_usb_controllers.ps1 -All -Pattern "*xHCI*" -Rescan
#>

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Force,
    [string]$Pattern,
    [switch]$Rescan
)

# Verify Administrator
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Error "This script must be run as Administrator."
    exit 1
}

if ($All) {
    Write-Host "Scanning ALL Universal Serial Bus controllers..." -ForegroundColor Cyan
    $raw = pnputil /enum-devices /class USB
}
else {
    Write-Host "Scanning hidden/disconnected Universal Serial Bus controllers..." -ForegroundColor Cyan
    $raw = pnputil /enum-devices /disconnected /class USB
}

$devices = @()
$current = $null

foreach ($line in $raw) {
    if ($line -match '^\s*Instance ID:\s+(.+)$') {
        if ($current) {
            $devices += [PSCustomObject]$current
        }

        $current = @{
            InstanceId  = $matches[1].Trim()
            Description = ""
            Status      = ""
        }
    }
    elseif ($current -and $line -match '^\s*Device Description:\s+(.+)$') {
        $current.Description = $matches[1].Trim()
    }
    elseif ($current -and $line -match '^\s*Status:\s+(.+)$') {
        $current.Status = $matches[1].Trim()
    }
}

if ($current) {
    $devices += [PSCustomObject]$current
}

if ($Pattern) {
    $devices = $devices | Where-Object {
        $_.Description -like $Pattern -or
        $_.InstanceId -like $Pattern
    }
}

if (-not $devices -or $devices.Count -eq 0) {
    Write-Host "No matching USB controller devices found." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "The following USB controller devices will be removed:" -ForegroundColor Yellow
$devices | Format-Table Description, Status, InstanceId -AutoSize

if ($All) {
    Write-Warning "You are about to remove ALL matching USB controller devices, including active USB hubs/controllers."
    Write-Warning "USB keyboard, mouse, serial adapters, ST-Link, and other USB devices may disconnect."
}

if (-not $Force) {
    Write-Host ""
    $reply = Read-Host "Continue? (Y/N)"

    if ($reply -notmatch '^[Yy]$') {
        Write-Host "Cancelled."
        exit 0
    }
}

Write-Host ""

foreach ($dev in $devices) {
    Write-Host "Removing $($dev.Description)..." -ForegroundColor Yellow
    pnputil /remove-device "$($dev.InstanceId)"
}

if ($Rescan) {
    Write-Host ""
    Write-Host "Forcing Plug-and-Play rediscovery..." -ForegroundColor Cyan
    pnputil /scan-devices
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "A reboot may be required."