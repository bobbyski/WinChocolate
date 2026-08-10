param(
    [string[]]$Roots = @("Sources", "WinFoundation\Sources")
)

$ErrorActionPreference = "Stop"

function Get-Documentation([string]$declaration) {
    $trimmed = $declaration.Trim()
    if ($trimmed -match '^(public|open)\s+(?:final\s+)?(?:indirect\s+)?(class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)') {
        return "Describes the public ``$($Matches[3])`` $($Matches[2])."
    }
    if ($trimmed -match '^(public|open)\s+extension\s+([^\s:{]+)') {
        return "Adds public behavior to ``$($Matches[2])``."
    }
    if ($trimmed -match '^(public|open)\s+typealias\s+([A-Za-z_][A-Za-z0-9_]*)') {
        return "The public ``$($Matches[2])`` type alias."
    }
    if ($trimmed -match '^(public|open)\s+(?:class\s+|static\s+)?(?:private\(set\)\s+)?(let|var)\s+([A-Za-z_][A-Za-z0-9_]*)') {
        $kind = if ($trimmed -match '\b(static|class)\b') { "type-level value" } else { "value" }
        return "The ``$($Matches[3])`` $kind."
    }
    if ($trimmed -match '^(public|open)\s+(?:class\s+|static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)') {
        return "Performs the ``$($Matches[2])`` operation."
    }
    if ($trimmed -match '^(public|open)\s+init(?:\?|!)?\b') {
        return "Creates a value with the supplied arguments."
    }
    if ($trimmed -match '^(public|open)\s+subscript\b') {
        return "Accesses the value at the supplied index."
    }
    return "This declaration is part of the public API."
}

$files = foreach ($root in $Roots) {
    Get-ChildItem -LiteralPath $root -Recurse -Filter *.swift -File
}

foreach ($file in $files) {
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -LiteralPath $file.FullName)) { $lines.Add($line) }
    $changed = $false
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i]
        if ($line -notmatch '^\s*(public|open)\s+' -or
            $line -match '^\s*(public|open)\s+(override|required|convenience)\b') {
            continue
        }
        $j = $i - 1
        while ($j -ge 0 -and ($lines[$j].Trim() -eq '' -or $lines[$j] -match '^\s*@')) { $j-- }
        if ($j -ge 0 -and ($lines[$j] -match '^\s*///' -or $lines[$j] -match '^\s*\*/')) {
            continue
        }
        $indent = $line.Substring(0, $line.Length - $line.TrimStart().Length)
        $lines.Insert($i, "$indent/// $(Get-Documentation $line)")
        $changed = $true
    }
    if ($changed) {
        [IO.File]::WriteAllLines($file.FullName, $lines, [Text.UTF8Encoding]::new($false))
    }
}
