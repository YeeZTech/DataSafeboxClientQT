# Verify a packaged Windows artifact is self-contained: every DLL named in the
# import table of every .dll/.exe in the package is either also in the package
# or provided by Windows / the VC++ redistributable.
#
# Why this exists: WCDB.dll used to import zlib1.dll while the SDK package did
# not ship that file, and it took until a user installed the package on a clean
# machine to surface as "the code execution cannot proceed because zlib1.dll
# was not found". It stayed hidden on x64 only because some unrelated software
# happened to leave a zlib1.dll on PATH. Reading the import table in CI catches
# this class of bug without using users as the detector.
#
# ASCII-only on purpose (runs under both Windows PowerShell 5.1 and pwsh 7).
#
# Usage:
#   pwsh .github/scripts/check_windows_dep_closure.ps1 -Root <extracted package>
#   ... -Allow extra.dll,other.dll   # explicit waivers; say why at the call site
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string[]]$Allow = @()
)
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\..\tools\pe-imports.ps1"

# Provided by Windows itself or by the VC++ redistributable, so not ours to
# ship. Matched against the lowercased full file name.
$systemPatterns = @(
    '^api-ms-win-.+\.dll$'
    '^ext-ms-.+\.dll$'
    # cabinet/imagehlp are additions over the data-safebox-core copy of this
    # script: that package contains neither vc_redist.exe (imports cabinet) nor
    # opengl32sw.dll (delay-imports imagehlp), so it never reached them. Both are
    # shipped by Windows -- verified present in System32 with Microsoft as the
    # file's company. Worth folding back into the DSCC copy to keep the two in sync.
    '^(kernel32|kernelbase|ntdll|user32|gdi32|gdi32full|gdiplus|advapi32|shell32|shcore|shlwapi|ole32|oleaut32|combase|comdlg32|comctl32|imm32|version|winmm|ws2_32|mswsock|wsock32|crypt32|bcrypt|bcryptprimitives|ncrypt|cryptbase|secur32|sspicli|wintrust|dbghelp|dbgeng|dbgcore|psapi|iphlpapi|dnsapi|netapi32|userenv|mpr|authz|wtsapi32|rpcrt4|setupapi|cfgmgr32|propsys|powrprof|uxtheme|dwmapi|opengl32|glu32|d3d9|d3d11|d3d12|dxgi|dxva2|d2d1|dwrite|winhttp|wininet|urlmon|msi|normaliz|msimg32|oleacc|uiautomationcore|windowscodecs|mf|mfplat|mfreadwrite|avrt|dcomp|coremessaging|ucrtbase|cabinet|imagehlp)\.dll$'
    '^winspool\.drv$'
    '^(msvcrt|msvcp\d+(_\w+)?|vcruntime\d+(_\d+)?|concrt\d+|vccorlib\d+|ucrtbased)\.dll$'
)

# Second tier after the pattern list: anything Windows itself ships in the system
# directory. The pattern list alone turned into whack-a-mole -- cabinet, imagehlp
# and cryptsp all showed up one build at a time, every one of them a genuine
# Windows DLL pulled in by Qt/D3D/vc_redist rather than anything we build. What
# resolves this way is printed, so a wrong classification stays reviewable instead
# of silently passing.
$systemDir = [Environment]::SystemDirectory

if (-not (Test-Path $Root)) { throw "package directory does not exist: $Root" }
$rootFull = (Resolve-Path $Root).Path

$binaries = Get-ChildItem -LiteralPath $rootFull -Recurse -File |
    Where-Object { $_.Extension -in @('.dll', '.exe') } |
    Sort-Object FullName
if (-not $binaries) { throw "no .dll/.exe found under $rootFull -- empty package?" }

$present = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($b in $binaries) { [void]$present.Add($b.Name) }

$allowed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($a in $Allow) { if ($a) { [void]$allowed.Add($a.Trim()) } }

function Test-SystemDll([string]$name) {
    $lower = $name.ToLowerInvariant()
    foreach ($p in $systemPatterns) {
        if ($lower -match $p) { return $true }
    }
    return $false
}

Write-Host "=== dependency closure: $rootFull ($($binaries.Count) binaries) ==="

$missing = @()
$waived  = @()
$assumed = @()
foreach ($b in $binaries) {
    $rel = $b.FullName.Substring($rootFull.Length).TrimStart('\', '/')
    try {
        $imports = Get-PeImportedDlls -Path $b.FullName
    } catch {
        # Not a PE (e.g. a resource file that happens to end in .dll). Skip it,
        # but say so -- a silent skip would be a hole in the check.
        Write-Host "  skip (unparseable): $rel -- $($_.Exception.Message)"
        continue
    }
    foreach ($imp in $imports) {
        if ($present.Contains($imp)) { continue }
        if (Test-SystemDll $imp)     { continue }
        if (Test-Path -LiteralPath (Join-Path $systemDir $imp)) {
            $assumed += [pscustomobject]@{ Binary = $rel; Dll = $imp }
            continue
        }
        if ($allowed.Contains($imp)) {
            $waived += [pscustomobject]@{ Binary = $rel; Missing = $imp }
            continue
        }
        $missing += [pscustomobject]@{ Binary = $rel; Missing = $imp }
    }
}

if ($assumed) {
    Write-Host ""
    Write-Host "--- resolved from the Windows system directory ---"
    $assumed | Sort-Object Dll, Binary | Format-Table -AutoSize | Out-String | Write-Host
}

if ($waived) {
    Write-Host ""
    Write-Host "--- explicitly waived ---"
    $waived | Sort-Object Missing, Binary | Format-Table -AutoSize | Out-String | Write-Host
}

if ($missing) {
    $names = $missing | Select-Object -ExpandProperty Missing | Sort-Object -Unique
    Write-Host ""
    Write-Host "--- missing from package ---"
    $missing | Sort-Object Missing, Binary | Format-Table -AutoSize | Out-String | Write-Host
    foreach ($n in $names) { Write-Host "::error::package is missing $n" }
    throw "dependency closure incomplete: $($names -join ', ')"
}

Write-Host "OK: every non-system dependency is present in the package."
