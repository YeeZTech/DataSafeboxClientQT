# Read a PE file (.dll/.exe) import table and list the DLLs it depends on.
#
# Pure .NET, no dumpbin: dumpbin lives under VS's VC\Tools\MSVC\<ver>\bin\ and
# is not on PATH, so using it means hunting for it via vswhere -- and this runs
# on both the x64 and arm64 runners, where one less external dependency is one
# less platform difference.
#
# ASCII-only on purpose (runs under both Windows PowerShell 5.1 and pwsh 7,
# which disagree about the default encoding of a BOM-less script file).
#
# Usage:
#   . tools/pe-imports.ps1                 # dot-source, gives Get-PeImportedDlls
#   pwsh tools/pe-imports.ps1 -Path x.dll  # run directly, one DLL name per line
param([string]$Path)

function Get-PeImportedDlls {
    [OutputType([string[]])]
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x40) { throw "${Path}: too small to be a PE file" }
    if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw "${Path}: no MZ header, not a PE file" }

    $peOff = [int][BitConverter]::ToUInt32($bytes, 0x3C)
    if ($peOff -le 0 -or ($peOff + 24) -gt $bytes.Length -or
        [BitConverter]::ToUInt32($bytes, $peOff) -ne 0x00004550) {   # "PE\0\0"
        throw "${Path}: invalid PE signature"
    }

    $numSections   = [int][BitConverter]::ToUInt16($bytes, $peOff + 6)
    $optHeaderSize = [int][BitConverter]::ToUInt16($bytes, $peOff + 20)
    $optOff        = $peOff + 24
    $magic         = [BitConverter]::ToUInt16($bytes, $optOff)
    # Data directory offset inside the optional header: +96 for PE32, +112 for
    # PE32+ -- the extra 16 bytes are ImageBase/SizeOfStack*/SizeOfHeap* going
    # from 32-bit to 64-bit.
    if ($magic -eq 0x10B) {
        $dataDirOff = $optOff + 96
    } elseif ($magic -eq 0x20B) {
        $dataDirOff = $optOff + 112
    } else {
        throw ("{0}: unknown optional header magic 0x{1:X}" -f $Path, $magic)
    }

    $sectionOff = $optOff + $optHeaderSize
    $sections = @()
    for ($i = 0; $i -lt $numSections; $i++) {
        $s = $sectionOff + ($i * 40)
        if (($s + 40) -gt $bytes.Length) { break }
        $sections += [pscustomobject]@{
            VirtualSize    = [int][BitConverter]::ToUInt32($bytes, $s + 8)
            VirtualAddress = [int][BitConverter]::ToUInt32($bytes, $s + 12)
            RawSize        = [int][BitConverter]::ToUInt32($bytes, $s + 16)
            RawOffset      = [int][BitConverter]::ToUInt32($bytes, $s + 20)
        }
    }

    # RVA -> file offset. Anything outside every section returns -1, which the
    # callers treat as "unreadable" rather than reading at a bogus offset.
    function ConvertTo-FileOffset([int]$rva) {
        foreach ($sec in $sections) {
            $span = [Math]::Max($sec.VirtualSize, $sec.RawSize)
            if ($rva -ge $sec.VirtualAddress -and $rva -lt ($sec.VirtualAddress + $span)) {
                return ($rva - $sec.VirtualAddress + $sec.RawOffset)
            }
        }
        return -1
    }

    function Read-AsciiZ([int]$offset) {
        if ($offset -lt 0 -or $offset -ge $bytes.Length) { return $null }
        $end = $offset
        while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
        if ($end -le $offset) { return $null }
        return [System.Text.Encoding]::ASCII.GetString($bytes, $offset, $end - $offset)
    }

    $names = New-Object System.Collections.Generic.List[string]

    # Data directory 1 = import table. IMAGE_IMPORT_DESCRIPTOR is 20 bytes per
    # entry, terminated by an all-zero entry.
    $impRva = [int][BitConverter]::ToUInt32($bytes, $dataDirOff + 8)
    if ($impRva -ne 0) {
        $off = ConvertTo-FileOffset $impRva
        while ($off -ge 0 -and ($off + 20) -le $bytes.Length) {
            $origThunk  = [BitConverter]::ToUInt32($bytes, $off)
            $nameRva    = [int][BitConverter]::ToUInt32($bytes, $off + 12)
            $firstThunk = [BitConverter]::ToUInt32($bytes, $off + 16)
            if ($origThunk -eq 0 -and $nameRva -eq 0 -and $firstThunk -eq 0) { break }
            $n = Read-AsciiZ (ConvertTo-FileOffset $nameRva)
            if ($n) { [void]$names.Add($n) }
            $off += 20
        }
    }

    # Data directory 13 = delay-load import table, 32 bytes per entry. Bit 0 of
    # Attributes means the table holds RVAs; the VC6-era VA variant is skipped
    # rather than guessed at -- nothing we build emits it.
    $delayRva = [int][BitConverter]::ToUInt32($bytes, $dataDirOff + (13 * 8))
    if ($delayRva -ne 0) {
        $off = ConvertTo-FileOffset $delayRva
        while ($off -ge 0 -and ($off + 32) -le $bytes.Length) {
            $attrs   = [BitConverter]::ToUInt32($bytes, $off)
            $nameRva = [int][BitConverter]::ToUInt32($bytes, $off + 4)
            if ($nameRva -eq 0) { break }
            if (($attrs -band 1) -eq 1) {
                $n = Read-AsciiZ (ConvertTo-FileOffset $nameRva)
                if ($n) { [void]$names.Add($n) }
            }
            $off += 32
        }
    }

    return ($names | Sort-Object -Unique)
}

if ($Path) {
    Get-PeImportedDlls -Path $Path
}
