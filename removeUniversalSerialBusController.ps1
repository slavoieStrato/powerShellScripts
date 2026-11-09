# Run as Administrator

Write-Host "Enumerating USB devices..." -ForegroundColor Cyan

# Get all USB devices
$usbDevices = pnputil /enum-devices /class USB | Select-String "Instance ID"

# Extract Instance IDs
$ids = $usbDevices | ForEach-Object {
    ($_ -split ":")[1].Trim()
}

# Remove each device
foreach ($id in $ids) {
    Write-Host "Removing $id" -ForegroundColor Yellow
    pnputil /remove-device "$id"
}

Write-Host "Done. You may need to reboot." -ForegroundColor Green