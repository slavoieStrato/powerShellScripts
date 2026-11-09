#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"

function Get-FreeSpace {
    $Volume = Get-Volume -DriveLetter C
    return $Volume.SizeRemaining
}

function Show-DiskSpace {
    param([string]$Title)

    Write-Host "`n=== $Title ==="

    Get-Volume -DriveLetter C |
        Select-Object DriveLetter,
            @{N='UsedGiB'; E={[math]::Round(($_.Size - $_.SizeRemaining) / 1GB, 2)}},
            @{N='FreeGiB'; E={[math]::Round($_.SizeRemaining / 1GB, 2)}},
            @{N='TotalGiB';E={[math]::Round($_.Size / 1GB, 2)}} |
        Format-Table -AutoSize
}

function Show-Recovered {
    param(
        [string]$Name,
        [long]$Before
    )

    $After = Get-FreeSpace
    $Recovered = ($After - $Before) / 1GB

    Write-Host ("{0}: {1:N2} GiB recovered" -f $Name, $Recovered)
}


# ============================================================
# Starting state
# ============================================================

$StartFree = Get-FreeSpace

Show-DiskSpace "Disk space BEFORE"


# ============================================================
# 1. Recycle Bin
# ============================================================

Write-Host "`n=== Clearing Recycle Bin ==="
$Before = Get-FreeSpace

Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue

Show-Recovered "Recycle Bin" $Before


# ============================================================
# 2. VSS / Shadow Copies
# ============================================================

Write-Host "`n=== Deleting C: shadow copies ==="
$Before = Get-FreeSpace

vssadmin delete shadows /for=C: /all /quiet

Show-Recovered "Shadow copies" $Before


# ============================================================
# 3. Windows TEMP
# ============================================================

Write-Host "`n=== Clearing Windows TEMP ==="
$Before = Get-FreeSpace

if (Test-Path "C:\Windows\Temp") {
    Get-ChildItem "C:\Windows\Temp" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Show-Recovered "Windows TEMP" $Before


# ============================================================
# 4. User TEMP
# ============================================================

Write-Host "`n=== Clearing User TEMP ==="
$Before = Get-FreeSpace

if (Test-Path $env:TEMP) {
    Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Show-Recovered "User TEMP" $Before


# ============================================================
# 5. Windows Error Reporting
# ============================================================

Write-Host "`n=== Clearing Windows Error Reporting ==="
$Before = Get-FreeSpace

$WERPaths = @(
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
)

foreach ($Path in $WERPaths) {
    if (Test-Path $Path) {
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Show-Recovered "Windows Error Reporting" $Before


# ============================================================
# 6. Live Kernel Reports
# ============================================================

Write-Host "`n=== Clearing LiveKernelReports ==="
$Before = Get-FreeSpace

$LiveKernelPath = "C:\Windows\LiveKernelReports"

if (Test-Path $LiveKernelPath) {
    Get-ChildItem $LiveKernelPath -Recurse -File -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Show-Recovered "LiveKernelReports" $Before


# ============================================================
# 7. Delivery Optimization Cache
# ============================================================

Write-Host "`n=== Clearing Delivery Optimization Cache ==="
$Before = Get-FreeSpace

try {
    Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
}
catch {
    Write-Warning "Could not clear Delivery Optimization cache: $($_.Exception.Message)"
}

Show-Recovered "Delivery Optimization" $Before


# ============================================================
# 8. Windows Component Store / WinSxS
# ============================================================

Write-Host "`n=== Windows Component Store Cleanup ==="
Write-Host "This may take several minutes..."

$Before = Get-FreeSpace

Dism.exe /Online /Cleanup-Image /StartComponentCleanup

Show-Recovered "Component Store" $Before


# ============================================================
# Final results
# ============================================================

$EndFree = Get-FreeSpace
$TotalRecovered = ($EndFree - $StartFree) / 1GB

Show-DiskSpace "Disk space AFTER"

Write-Host "`n========================================"
Write-Host "          CLEANUP SUMMARY"
Write-Host "========================================"

Write-Host ("Free before : {0:N2} GiB" -f ($StartFree / 1GB))
Write-Host ("Free after  : {0:N2} GiB" -f ($EndFree / 1GB))
Write-Host ("Recovered   : {0:N2} GiB" -f $TotalRecovered)

Write-Host "========================================`n"


# ============================================================
# Remaining VSS information
# ============================================================

Write-Host "=== Remaining Shadow Storage ==="
vssadmin list shadowstorage