$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$canonical = Join-Path $repoRoot "AGENTS.md"
$mirrors = @(
    (Join-Path $repoRoot "CLAUDE.md"),
    (Join-Path $repoRoot ".cursor/rules/agents.mdc")
)

if (-not (Test-Path -LiteralPath $canonical)) {
    Write-Error "Missing canonical rules file: $canonical"
    exit 1
}

$canonicalBytes = [IO.File]::ReadAllBytes($canonical)
$canonicalText = [Text.Encoding]::UTF8.GetString($canonicalBytes)

if ($canonicalBytes -contains 0) {
    Write-Error "AGENTS.md contains NUL bytes."
    exit 1
}

if ([regex]::IsMatch($canonicalText, '(?<!\r)\n')) {
    Write-Error "AGENTS.md has bare LF line endings; expected CRLF."
    exit 1
}

$requiredMarkers = @(
    "Repository Agent Rules",
    "alwaysApply: true",
    "MaxScript",
    "tools/check-bs-retarget-script.ps1",
    "docs/BsRetargetTools-validation-checklist.md"
)

foreach ($marker in $requiredMarkers) {
    if (-not $canonicalText.Contains($marker)) {
        Write-Error "Required marker missing from AGENTS.md: $marker"
        exit 1
    }
}

foreach ($mirror in $mirrors) {
    if (-not (Test-Path -LiteralPath $mirror)) {
        Write-Error "Missing mirror rules file: $mirror"
        exit 1
    }

    $mirrorBytes = [IO.File]::ReadAllBytes($mirror)
    if ($mirrorBytes.Length -ne $canonicalBytes.Length) {
        Write-Error "Mirror length differs from AGENTS.md: $mirror"
        exit 1
    }

    for ($i = 0; $i -lt $canonicalBytes.Length; $i++) {
        if ($canonicalBytes[$i] -ne $mirrorBytes[$i]) {
            Write-Error "Mirror content differs from AGENTS.md: $mirror"
            exit 1
        }
    }
}

Write-Host "Agent rules check completed."
