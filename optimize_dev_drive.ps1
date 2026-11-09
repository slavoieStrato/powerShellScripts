$Vhdx = "C:\DevDrive\DevDrive.vhdx"

# 1. Verify ReFS has no leaks
refsutil leak P: /d

# 2. Tell the VHDX which ReFS regions are unused
Optimize-Volume -DriveLetter P -ReTrim -Verbose

# 3. Close applications using P: before continuing

# 4. Compact the VHDX offline
Dismount-VHD $Vhdx
Optimize-VHD $Vhdx -Mode Prezeroed -Verbose
Mount-VHD $Vhdx

# 5. Report result
Get-VHD $Vhdx |
    Select VhdType,
        @{N='FileSizeGiB';E={[math]::Round($_.FileSize/1GB,2)}},
        @{N='VirtualSizeGiB';E={[math]::Round($_.Size/1GB,2)}}

Get-Volume P |
    Select DriveLetter,
        @{N='UsedGiB';E={[math]::Round(($_.Size-$_.SizeRemaining)/1GB,2)}},
        @{N='FreeGiB';E={[math]::Round($_.SizeRemaining/1GB,2)}}