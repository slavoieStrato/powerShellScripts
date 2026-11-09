<#
.SYNOPSIS
  Find Defender scan hotspots during Cursor / Claude / compile workloads and map gaps to Dev Drive vs exclusions.

.DESCRIPTION
  Uses Microsoft Defender performance recording (Get-MpPerformanceReport) and compares
  hot paths, processes, and extensions against current MpPreference exclusions and
  Dev Drive volume(s). Outputs actionable recommendations; optional -EmitCommands
  prints Add-MpPreference lines for gaps only.

  Recording requires an elevated shell. Analysis of an existing .etl does not.

  Exclusions reduce protection — prefer moving caches, build trees, and repos to
  Dev Drive (ReFS) before broad path/process exclusions.

.PARAMETER RecordSeconds
  If greater than 0, capture a new trace for this many seconds (admin required).
  Run Cursor/Claude/builds during the window.

.PARAMETER EtlPath
  Trace file path. Default: C:\Temp\defender_scan.etl

.PARAMETER TopN
  How many top entries per report section to pull from the trace.

.PARAMETER FocusDevAi
  When set (default), filter results to AI IDE / agent / common dev tool patterns.

.PARAMETER EmitCommands
  Print suggested Add-MpPreference commands for uncovered high-impact items.

.PARAMETER ShowWatchlist
  Print status of known Cursor/Claude/cache locations even before trace analysis.

.EXAMPLE
  # Record 120s while you build in Cursor, then analyze:
  .\ms_defender_monit.ps1 -RecordSeconds 120

.EXAMPLE
  .\ms_defender_monit.ps1 -EtlPath C:\Temp\defender_scan.etl -EmitCommands
#>
[CmdletBinding()]
param(
    [int] $RecordSeconds = 0,
    [string] $EtlPath = 'C:\Temp\defender_scan.etl',
    [int] $TopN = 30,
    [switch] $FocusDevAi,
    [switch] $EmitCommands,
    [switch] $ShowWatchlist,
    [string[]] $DevDriveLetters = @('P')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('FocusDevAi')) {
    $FocusDevAi = $true
}

$FocusPattern = '(?i)(cursor|claude|codex|\.cursor|\.claude|\.codex|openai|anthropic|node(?:\.exe)?|npm|pnpm|yarn|esbuild|vite|webpack|tsc\.exe|rustc|cargo|cmake|ninja|gcc|g\+\+|cc1|make\.exe|git\.exe|python|\.vscode|extensions\\|AppData\\Local\\Programs\\cursor|AppData\\Roaming\\Cursor|AppData\\Local\\Cursor|AppData\\Roaming\\Claude|AppData\\Local\\Claude|msbuild|dotnet|\.cache|node_modules|\.git\\|build\\|out\\|target\\|dist\\|\.o$|\.obj$|\.elf$|\.su$|\.d$)'

function Get-NormalizedPath {
    param([string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        $full = [System.IO.Path]::GetFullPath($Path.Trim())
        return $full.TrimEnd('\')
    }
    catch {
        return $Path.Trim().TrimEnd('\')
    }
}

function Get-DevDriveRootMap {
    param([string[]] $Letters)
    $map = @{}
    foreach ($letter in $Letters) {
        $l = $letter.TrimEnd(':').ToUpperInvariant()
        $root = "${l}:\"
        if (Test-Path -LiteralPath $root) {
            $vol = Get-Volume -DriveLetter $l -ErrorAction SilentlyContinue
            $map[$root] = [PSCustomObject]@{
                Letter = $l
                Label  = $vol.FileSystemLabel
                IsReFS = ($vol.FileSystem -eq 'ReFS')
            }
        }
    }
    return $map
}

function Test-PathOnDevDrive {
    param(
        [string] $Path,
        [hashtable] $DevRoots
    )
    $norm = Get-NormalizedPath $Path
    if (-not $norm) { return $false }
    foreach ($root in $DevRoots.Keys) {
        if ($norm.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-DefenderExclusionSnapshot {
    $pref = Get-MpPreference
    $paths = @($pref.ExclusionPath | ForEach-Object { Get-NormalizedPath $_ } | Where-Object { $_ })
    $procs = @($pref.ExclusionProcess)
    $exts  = @($pref.ExclusionExtension | ForEach-Object {
            $e = $_.ToString().Trim()
            if ($e -and $e[0] -ne '.') { ".$e" } else { $e }
        })
    [PSCustomObject]@{
        Paths     = $paths
        Processes = $procs
        Extensions = $exts
    }
}

function Test-DefenderPathExcluded {
    param(
        [string] $Path,
        $Snapshot
    )
    $norm = Get-NormalizedPath $Path
    if (-not $norm) { return $false }
    foreach ($ex in $Snapshot.Paths) {
        if ($norm.StartsWith($ex, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-DefenderProcessExcluded {
    param(
        [string] $ProcessPath,
        $Snapshot
    )
    if ([string]::IsNullOrWhiteSpace($ProcessPath)) { return $false }
    $norm = Get-NormalizedPath $ProcessPath
    $base = [System.IO.Path]::GetFileName($norm)
    foreach ($ex in $Snapshot.Processes) {
        if ($ex -match '[\\/]') {
            $exNorm = Get-NormalizedPath $ex
            if ($norm -and $exNorm -and $norm.Equals($exNorm, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        elseif ($base -and $ex -and $base.Equals($ex, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-DefenderExtensionExcluded {
    param(
        [string] $Path,
        $Snapshot
    )
    $ext = [System.IO.Path]::GetExtension($Path)
    if (-not $ext) { return $false }
    return $Snapshot.Extensions -contains $ext
}

function Get-PathExclusionCandidate {
    param([string] $Path)
    $norm = Get-NormalizedPath $Path
    if (-not $norm) { return $null }
    if (Test-Path -LiteralPath $norm -PathType Leaf) {
        $norm = [System.IO.Path]::GetDirectoryName($norm)
    }
    # Prefer stable parent folders for AI tools and caches
    $segments = @(
        '\.cursor', '\.claude', '\.codex', '\AppData\Local\Cursor', '\AppData\Roaming\Cursor',
        '\AppData\Local\Claude', '\AppData\Roaming\Claude', '\AppData\Local\Programs\cursor',
        '\node_modules', '\.cache', '\plugins\cache', '\.tmp\plugins'
    )
    foreach ($seg in $segments) {
        $m = [regex]::Match($norm, "(?i)$([regex]::Escape($seg))")
        if ($m.Success) {
            $candidate = $norm.Substring(0, $m.Index + $m.Length).TrimEnd('\')
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $norm
}

function Get-RecommendationKind {
    param(
        [string] $Path,
        [string] $ProcessPath,
        [hashtable] $DevRoots,
        $Snapshot,
        [ValidateSet('Path', 'Process', 'Extension')]
        [string] $ItemType
    )
    if ($ItemType -eq 'Process') {
        if (Test-DefenderProcessExcluded -ProcessPath $ProcessPath -Snapshot $Snapshot) {
            return 'Covered'
        }
        return 'ExclusionProcess'
    }

    if ($ItemType -eq 'Extension') {
        if (Test-DefenderExtensionExcluded -Path $Path -Snapshot $Snapshot) {
            return 'Covered'
        }
        return 'ExclusionExtension'
    }

    if (Test-DefenderPathExcluded -Path $Path -Snapshot $Snapshot) {
        return 'Covered'
    }
    if (Test-PathOnDevDrive -Path $Path -DevRoots $DevRoots) {
        return 'OnDevDrive'
    }

    $norm = Get-NormalizedPath $Path
    if ($norm -match '(?i)\\(Windows|Program Files|Program Files \(x86\))\\') {
        return 'ExclusionProcessOrReview'
    }
    if ($norm -match '(?i)\\Users\\[^\\]+\\(Desktop|Documents|Downloads)\\') {
        return 'MoveToDevDrive'
    }
    if ($norm -match '(?i)\\Users\\') {
        return 'MoveToDevDriveOrExclusionPath'
    }
    return 'ExclusionPathOrReview'
}

function Test-FocusMatch {
    param([string] $Text)
    if (-not $FocusDevAi) { return $true }
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return $Text -match $FocusPattern
}

function Get-AiDevWatchlist {
    $userHome = $env:USERPROFILE
    @(
        "$userHome\.cursor",
        "$userHome\.claude",
        "$userHome\.codex",
        "$userHome\AppData\Local\Programs\cursor",
        "$userHome\AppData\Roaming\Cursor",
        "$userHome\AppData\Local\Cursor",
        "$userHome\AppData\Roaming\Claude",
        "$userHome\AppData\Local\Claude",
        'P:\repos',
        'P:\.cache',
        'P:\.cursor',
        'P:\.claude',
        'P:\Temp'
    ) | ForEach-Object {
        $p = Get-NormalizedPath $_
        [PSCustomObject]@{
            Path   = $p
            Exists = (Test-Path -LiteralPath $p)
        }
    }
}

function Get-NotePropertyValue {
    param(
        $Object,
        [string] $Name
    )
    if (-not $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function Expand-MpFolderTree {
    param(
        $Nodes,
        [string] $Prefix = ''
    )
    foreach ($node in @($Nodes)) {
        if (-not $node) { continue }
        $segment = [string] $node.Path
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }

        if ($segment -match '^[a-zA-Z]:\\') {
            $current = Get-NormalizedPath $segment
        }
        elseif ($segment -match '^[a-zA-Z]:$') {
            $current = ($segment + '\')
        }
        elseif ($Prefix) {
            $current = Join-Path -Path $Prefix -ChildPath $segment
        }
        else {
            $current = $segment
        }

        $yield = [PSCustomObject]@{
            Path          = $current
            Count         = $node.Count
            TotalDuration = $node.TotalDuration
        }
        $yield

        $childFolders = Get-NotePropertyValue -Object $node -Name 'Folder'
        if ($childFolders) {
            Expand-MpFolderTree -Nodes $childFolders -Prefix $current
        }
    }
}

function Format-DurationMs {
    param($Duration)
    if ($Duration -is [TimeSpan]) {
        return [math]::Round($Duration.TotalMilliseconds, 2)
    }
    if ($Duration -match '([\d\.]+)ms$') {
        return [double]$Matches[1]
    }
    return $Duration
}

function Register-DefenderHotspot {
    param(
        [System.Collections.Generic.List[object]] $FindingStore,
        [string] $Category,
        [string] $ItemPath,
        [string] $ProcessFile,
        $TotalDuration,
        [int] $Count,
        [string] $Recommendation,
        [string] $ExclusionHint
    )
    $key = "$Category|$ItemPath|$ProcessFile"
    $existing = $FindingStore | Where-Object { "$($_.Category)|$($_.Path)|$($_.ProcessPath)" -eq $key } | Select-Object -First 1
    if ($existing) {
        $existing.Count += $Count
        $existing.TotalDurationMs += (Format-DurationMs $TotalDuration)
        return
    }
    $FindingStore.Add([PSCustomObject]@{
            Category         = $Category
            Path             = $ItemPath
            ProcessPath      = $ProcessFile
            Count            = $Count
            TotalDurationMs  = (Format-DurationMs $TotalDuration)
            Recommendation   = $Recommendation
            ExclusionHint    = $ExclusionHint
        })
}

# --- Main ---

$devRoots = Get-DevDriveRootMap -Letters $DevDriveLetters
$snapshot = Get-DefenderExclusionSnapshot

Write-Host ''
Write-Host '=== Defender monitor: Dev Drive + exclusion gap analysis ===' -ForegroundColor Cyan
Write-Host "Dev Drive roots: $($devRoots.Keys -join ', ')"
Write-Host "Exclusion paths: $($snapshot.Paths.Count) | processes: $($snapshot.Processes.Count) | extensions: $($snapshot.Extensions.Count)"

if ($ShowWatchlist) {
    Write-Host ''
    Write-Host '--- Watchlist (Cursor / Claude / Dev Drive layout) ---' -ForegroundColor Yellow
    foreach ($w in Get-AiDevWatchlist) {
        if (-not $w.Path) { continue }
        $onDev = Test-PathOnDevDrive -Path $w.Path -DevRoots $devRoots
        $excl  = Test-DefenderPathExcluded -Path $w.Path -Snapshot $snapshot
        $status = if (-not $w.Exists) { 'missing' }
        elseif ($excl) { 'excluded' }
        elseif ($onDev) { 'on DevDrive (ReFS)' }
        else { 'NOT excluded - on system volume' }
        Write-Host ("  [{0}] {1}" -f $status, $w.Path)
    }
}

if ($RecordSeconds -gt 0) {
    $etlDir = Split-Path -LiteralPath $EtlPath -Parent
    if (-not (Test-Path -LiteralPath $etlDir)) {
        New-Item -ItemType Directory -Path $etlDir -Force | Out-Null
    }
    Write-Host ''
    Write-Host "Recording Defender scans for $RecordSeconds s -> $EtlPath" -ForegroundColor Yellow
    Write-Host 'Keep Cursor/Claude/build active during this window.'
    New-MpPerformanceRecording -RecordTo $EtlPath -Seconds $RecordSeconds
}

if (-not (Test-Path -LiteralPath $EtlPath)) {
    Write-Host ''
    Write-Host "No trace at $EtlPath. Run with -RecordSeconds 60 (admin) while working, or pass -EtlPath." -ForegroundColor Red
    if (-not $ShowWatchlist) {
        Write-Host 'Tip: -ShowWatchlist audits known folders without a trace.'
    }
    return
}

Write-Host ''
Write-Host "--- Trace overview: $EtlPath ---" -ForegroundColor Yellow
$overview = Get-MpPerformanceReport -Path $EtlPath -Overview
$overview | Format-List

$findings = [System.Collections.Generic.List[object]]::new()

Write-Verbose "Pulling TopFiles (TopN=$TopN)"
$fileReport = Get-MpPerformanceReport -Path $EtlPath -TopFiles $TopN -TopProcessesPerFile 2
Write-Verbose 'TopFiles done'
foreach ($f in @($fileReport.TopFiles)) {
    if (-not (Test-FocusMatch $f.Path)) { continue }
    $kind = Get-RecommendationKind -Path $f.Path -ProcessPath '' -DevRoots $devRoots -Snapshot $snapshot -ItemType 'Path'
    $hint = Get-PathExclusionCandidate -Path $f.Path
    Register-DefenderHotspot -FindingStore $findings -Category 'HotFile' -ItemPath $f.Path -ProcessFile '' `
        -TotalDuration $f.TotalDuration -Count $f.Count -Recommendation $kind -ExclusionHint $hint
}

Write-Verbose 'Pulling TopProcesses'
$procReport = Get-MpPerformanceReport -Path $EtlPath -TopProcesses $TopN -TopPathsPerProcess 5 -TopPathsDepth 4
Write-Verbose 'TopProcesses done'
foreach ($p in @($procReport.TopProcesses)) {
    if (-not (Test-FocusMatch $p.ProcessPath)) { continue }
    $kind = Get-RecommendationKind -Path '' -ProcessPath $p.ProcessPath -DevRoots $devRoots -Snapshot $snapshot -ItemType 'Process'
    Register-DefenderHotspot -FindingStore $findings -Category 'HotProcess' -ItemPath '' -ProcessFile $p.ProcessPath `
        -TotalDuration $p.TotalDuration -Count $p.Count -Recommendation $kind -ExclusionHint $p.ProcessPath
    $procFolders = Get-NotePropertyValue -Object $p -Name 'Folder'
    if ($procFolders) {
        foreach ($sub in Expand-MpFolderTree -Nodes $procFolders -Prefix '') {
            if (-not (Test-FocusMatch $sub.Path)) { continue }
            $pKind = Get-RecommendationKind -Path $sub.Path -ProcessPath $p.ProcessPath -DevRoots $devRoots -Snapshot $snapshot -ItemType 'Path'
            Register-DefenderHotspot -FindingStore $findings -Category 'ProcessVolume' -ItemPath $sub.Path -ProcessFile $p.ProcessPath `
                -TotalDuration $sub.TotalDuration -Count $sub.Count -Recommendation $pKind -ExclusionHint (Get-PathExclusionCandidate $sub.Path)
        }
    }
}

Write-Verbose 'Pulling TopPaths'
$pathReport = Get-MpPerformanceReport -Path $EtlPath -TopPaths $TopN -TopPathsDepth 4 -TopProcessesPerPath 3
Write-Verbose 'TopPaths done'
foreach ($tp in @($pathReport.TopPaths)) {
    $nodes = @(
        [PSCustomObject]@{
            Path          = $tp.Path
            Count         = $tp.Count
            TotalDuration = $tp.TotalDuration
            Folder        = (Get-NotePropertyValue -Object $tp -Name 'Folder')
        }
    )
    foreach ($sub in Expand-MpFolderTree -Nodes $nodes -Prefix '') {
        if (-not (Test-FocusMatch $sub.Path)) { continue }
        $kind = Get-RecommendationKind -Path $sub.Path -ProcessPath '' -DevRoots $devRoots -Snapshot $snapshot -ItemType 'Path'
        Register-DefenderHotspot -FindingStore $findings -Category 'HotFolder' -ItemPath $sub.Path -ProcessFile '' `
            -TotalDuration $sub.TotalDuration -Count $sub.Count -Recommendation $kind -ExclusionHint (Get-PathExclusionCandidate $sub.Path)
    }
}

Write-Verbose 'Pulling TopExtensions'
$extReport = Get-MpPerformanceReport -Path $EtlPath -TopExtensions 15 -TopPathsPerExtension 3 -TopPathsDepth 3
Write-Verbose 'TopExtensions done'
foreach ($ext in @($extReport.TopExtensions)) {
    $name = $ext.Extension
    if (-not $name) { continue }
    if ($FocusDevAi -and $name -notmatch '(?i)^\.?(o|obj|elf|su|d|json|node|wasm|map|tsbuildinfo|sqlite)$') { continue }
    $samplePath = "dummy$name"
    $kind = Get-RecommendationKind -Path $samplePath -ProcessPath '' -DevRoots $devRoots -Snapshot $snapshot -ItemType 'Extension'
    Register-DefenderHotspot -FindingStore $findings -Category 'HotExtension' -ItemPath $name -ProcessFile '' `
        -TotalDuration $ext.TotalDuration -Count $ext.Count -Recommendation $kind -ExclusionHint $name
}

$ranked = $findings | Sort-Object TotalDurationMs -Descending

Write-Host ''
Write-Host '--- Ranked hotspots (Dev Drive vs exclusion) ---' -ForegroundColor Yellow
$ranked | Select-Object Category, TotalDurationMs, Count, Recommendation, Path, ProcessPath, ExclusionHint |
    Format-Table -AutoSize -Wrap

$gaps = $ranked | Where-Object {
    $_.Recommendation -notin @('Covered', 'OnDevDrive')
} | Sort-Object TotalDurationMs -Descending

Write-Host ''
Write-Host '--- Action summary ---' -ForegroundColor Green
$move = $gaps | Where-Object { $_.Recommendation -match 'MoveToDevDrive' }
$pathEx = $gaps | Where-Object { $_.Recommendation -match 'ExclusionPath' -and $_.ExclusionHint -and $_.Category -ne 'HotExtension' }
$procEx = $gaps | Where-Object { $_.Recommendation -eq 'ExclusionProcess' -and $_.ProcessPath }
$extEx  = $gaps | Where-Object { $_.Category -eq 'HotExtension' -and $_.Recommendation -eq 'ExclusionExtension' }

if ($move) {
    Write-Host ''
    Write-Host 'Prefer Dev Drive (move repo/cache/build output off C:):' -ForegroundColor Green
    $move | Select-Object -ExpandProperty Path -Unique | ForEach-Object { Write-Host "  $_" }
}

if ($pathEx) {
    Write-Host ''
    Write-Host 'Path exclusion candidates (narrowest useful folder):' -ForegroundColor Green
    $pathEx | Select-Object -ExpandProperty ExclusionHint -Unique | ForEach-Object { Write-Host "  $_" }
}

if ($procEx) {
    Write-Host ''
    Write-Host 'Process exclusion candidates (tooling binaries):' -ForegroundColor Green
    $procEx | Select-Object -ExpandProperty ProcessPath -Unique | ForEach-Object { Write-Host "  $_" }
}

if ($extEx) {
    Write-Host ''
    Write-Host 'Extension exclusions (use only if path/process exclusions are impractical):' -ForegroundColor DarkYellow
    $extEx | Select-Object -ExpandProperty Path -Unique | ForEach-Object { Write-Host "  $_" }
}

if ($EmitCommands -and $gaps) {
    Write-Host ''
    Write-Host '--- Suggested commands (review before applying; merge with ms_defender_dev_exclusions.ps1) ---' -ForegroundColor Magenta
    $seenPath = @{}
    foreach ($hint in ($pathEx | Select-Object -ExpandProperty ExclusionHint -Unique)) {
        $h = Get-NormalizedPath $hint
        if (-not $h) { continue }
        $key = $h.ToLowerInvariant()
        if ($seenPath[$key]) { continue }
        if (Test-DefenderPathExcluded -Path $h -Snapshot $snapshot) { continue }
        $seenPath[$key] = $true
        Write-Host "Add-MpPreference -ExclusionPath '$h'"
    }
    foreach ($proc in ($procEx | Select-Object -ExpandProperty ProcessPath -Unique)) {
        if (Test-DefenderProcessExcluded -ProcessPath $proc -Snapshot $snapshot) { continue }
        Write-Host "Add-MpPreference -ExclusionProcess '$proc'"
    }
    foreach ($ext in ($extEx | Select-Object -ExpandProperty Path -Unique)) {
        $e = $ext.ToString().Trim()
        if ($e[0] -ne '.') { $e = ".$e" }
        if ($snapshot.Extensions -contains $e) { continue }
        Write-Host "Add-MpPreference -ExclusionExtension $e"
    }
}

Write-Host ''
Write-Host 'Done. For a fresh capture: run elevated, use -RecordSeconds while Cursor/Claude compiles.' -ForegroundColor DarkGray
