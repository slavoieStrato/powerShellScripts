while ($true) {
    Get-PnpDevice -PresentOnly | Sort-Object FriendlyName | Out-File C:\temp\dev1.txt
    Start-Sleep 2
    Get-PnpDevice -PresentOnly | Sort-Object FriendlyName | Out-File C:\temp\dev2.txt
    Compare-Object (Get-Content C:\temp\dev1.txt) (Get-Content C:\temp\dev2.txt)
}