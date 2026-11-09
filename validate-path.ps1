<#
.SYNOPSIS
    Validate PATH environment variable entries.

.DESCRIPTION
    Checks both User and System PATH variables for:
      - Missing directories
      - Duplicates
      - Empty entries
      - Relative paths
      - Invalid environment variables
      - Trailing spaces
#>

function Test-PathVariable {

    param(
        [string]$Scope,
        [string]$PathValue
    )

    Write-Host ""
    Write-Host "========================="
    Write-Host "$Scope PATH"
    Write-Host "========================="

    $entries = $PathValue -split ';'

    $seen = @{}

    for ($i=0; $i -lt $entries.Count; $i++) {

        $original = $entries[$i]
        $entry = $original.Trim()

        if ($entry -eq "") {
            Write-Warning "[$i] Empty entry"
            continue
        }

        if ($original -ne $entry) {
            Write-Warning "[$i] Leading/trailing spaces"
        }

        # Expand environment variables
        $expanded = [Environment]::ExpandEnvironmentVariables($entry)

        # Unexpanded variable?
        if ($expanded -match '%.+%') {
            Write-Warning "[$i] Unresolved environment variable: $entry"
        }

        # Relative path?
        if (-not [System.IO.Path]::IsPathRooted($expanded)) {
            Write-Warning "[$i] Relative path: $entry"
            continue
        }

        # Normalize
        try {
            $full = [System.IO.Path]::GetFullPath($expanded)
        }
        catch {
            Write-Warning "[$i] Invalid path syntax: $entry"
            continue
        }

        $key = $full.ToLower()

        if ($seen.ContainsKey($key)) {
            Write-Warning "[$i] Duplicate of entry $($seen[$key])"
        }
        else {
            $seen[$key] = $i
        }

        if (Test-Path $full -PathType Container) {

            $exeCount = (Get-ChildItem $full -Filter *.exe -ErrorAction SilentlyContinue).Count

            Write-Host ("[{0}] OK      {1}" -f $i,$full)

            if ($exeCount -gt 0) {
                Write-Host ("      {0} executable(s)" -f $exeCount) -ForegroundColor DarkGray
            }
        }
        else {
            Write-Warning "[$i] Directory does not exist: $full"
        }
    }
}

$userPath   = [Environment]::GetEnvironmentVariable("PATH","User")
$systemPath = [Environment]::GetEnvironmentVariable("PATH","Machine")

Test-PathVariable "USER" $userPath
Test-PathVariable "SYSTEM" $systemPath