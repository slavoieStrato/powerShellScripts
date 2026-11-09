$time = Get-Date -Format "yyyyMMdd-HHmmss"
$dir = "$env:USERPROFILE\Desktop\dock-debug-$time"

New-Item -ItemType Directory -Path $dir

ipconfig /all > "$dir\ipconfig.txt"

Get-NetAdapter > "$dir\netadapter.txt"

Get-PnpDevice > "$dir\pnp.txt"

Get-PnpDevice -PresentOnly > "$dir\pnp-present.txt"

Get-WinEvent -LogName System -MaxEvents 200 |
Out-File "$dir\system-log.txt"

Get-WinEvent -ProviderName "Microsoft-Windows-USB-USBHUB3" -MaxEvents 200 |
Out-File "$dir\usb-log.txt"

Write-Host "Diagnostics saved to $dir"