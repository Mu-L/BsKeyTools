# Superpowers for Cursor - Install Script

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  Superpowers for Cursor - Install"
Write-Host "========================================"
Write-Host ""

# Config paths
$superpowersRepo = "https://github.com/obra/superpowers.git"
$codexDir = Join-Path $env:USERPROFILE ".codex"
$superpowersDir = Join-Path $codexDir "superpowers"
$cursorSkillsDir = Join-Path $env:USERPROFILE ".cursor\skills-cursor"
$cursorRulesDir = Join-Path $env:USERPROFILE ".cursor\rules"
$skillLinkPath = Join-Path $cursorSkillsDir "superpowers"

# Step 1: Check Git
Write-Host "[1/5] Checking Git..."
$gitCheck = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCheck) {
    Write-Host "  [X] Git not installed" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Git installed" -ForegroundColor Green

# Step 2: Create directories
Write-Host "[2/5] Creating directories..."
if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Path $codexDir -Force | Out-Null }
if (-not (Test-Path $cursorSkillsDir)) { New-Item -ItemType Directory -Path $cursorSkillsDir -Force | Out-Null }
if (-not (Test-Path $cursorRulesDir)) { New-Item -ItemType Directory -Path $cursorRulesDir -Force | Out-Null }
Write-Host "  [OK] Directories ready" -ForegroundColor Green

# Step 3: Clone or update repo
Write-Host "[3/5] Getting Superpowers repo..."
$skillsSourcePath = Join-Path $superpowersDir "skills"

# Check if repo exists and is valid (has skills directory)
$repoValid = (Test-Path $superpowersDir) -and (Test-Path $skillsSourcePath)

if ($repoValid) {
    Write-Host "  [-] Repo exists, updating..."
    Push-Location $superpowersDir
    $pullResult = git pull 2>&1
    $pullExitCode = $LASTEXITCODE
    Pop-Location
    if ($pullExitCode -eq 0) {
        Write-Host "  [OK] Updated" -ForegroundColor Green
    }
    else {
        Write-Host "  [!] Update failed: $pullResult" -ForegroundColor Yellow
    }
}
else {
    # Remove incomplete/corrupted directory if exists
    if (Test-Path $superpowersDir) {
        Write-Host "  [-] Removing incomplete repo..."
        Remove-Item -Path $superpowersDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "  [-] Cloning repo..."
    $cloneResult = git clone --depth 1 $superpowersRepo $superpowersDir 2>&1
    $cloneExitCode = $LASTEXITCODE
    
    if ($cloneExitCode -eq 0 -and (Test-Path $skillsSourcePath)) {
        Write-Host "  [OK] Cloned" -ForegroundColor Green
    }
    else {
        Write-Host "  [X] Clone failed: $cloneResult" -ForegroundColor Red
        Write-Host "  Please check network connection and try again."
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Step 4: Create link
Write-Host "[4/5] Creating skill link..."

# Check if link exists and is valid (can access brainstorming skill)
$linkValid = (Test-Path $skillLinkPath) -and (Test-Path (Join-Path $skillLinkPath "brainstorming"))

if ($linkValid) {
    Write-Host "  [-] Link exists and valid" -ForegroundColor Gray
}
else {
    # Remove broken link if exists
    if (Test-Path $skillLinkPath) {
        Write-Host "  [-] Removing broken link..."
        Remove-Item -Path $skillLinkPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Try to create junction
    $linkResult = cmd /c mklink /J "$skillLinkPath" "$skillsSourcePath" 2>&1
    
    if ((Test-Path $skillLinkPath) -and (Test-Path (Join-Path $skillLinkPath "brainstorming"))) {
        Write-Host "  [OK] Link created" -ForegroundColor Green
    }
    else {
        Write-Host "  [!] Link failed ($linkResult), copying..." -ForegroundColor Yellow
        Copy-Item -Path $skillsSourcePath -Destination $skillLinkPath -Recurse -Force
        if (Test-Path (Join-Path $skillLinkPath "brainstorming")) {
            Write-Host "  [OK] Copied" -ForegroundColor Green
        }
        else {
            Write-Host "  [X] Copy failed" -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
}

# Step 5: Create rule file
Write-Host "[5/5] Creating rule file..."
$globalRulePath = Join-Path $cursorRulesDir "superpowers.md"

$ruleContent = @'
# Superpowers for Cursor

<EXTREMELY_IMPORTANT>
You have superpowers. Superpowers are specialized skills for software development.

## Available Skills

Skills are in ~/.cursor/skills-cursor/superpowers/

### Core Skills (MANDATORY)

- **superpowers/using-superpowers** - MANDATORY: How to find and use skills.
- **superpowers/brainstorming** - MANDATORY before ANY creative work.
- **superpowers/systematic-debugging** - MANDATORY when encountering any bug.
- **superpowers/test-driven-development** - MANDATORY when implementing features.

### Planning Skills

- **superpowers/writing-plans** - Write detailed implementation plans.
- **superpowers/executing-plans** - Execute plans in batches.
- **superpowers/subagent-driven-development** - Execute tasks with subagents.

### Code Review Skills

- **superpowers/requesting-code-review** - Pre-review checklist.
- **superpowers/verification-before-completion** - MANDATORY when claiming work is complete.

## How to Use

1. **Automatic**: AI checks and uses relevant skills automatically
2. **Manual**: Reference with @superpowers/skill-name

IF A SKILL APPLIES, YOU MUST USE IT.
</EXTREMELY_IMPORTANT>
'@

Set-Content -Path $globalRulePath -Value $ruleContent -Encoding UTF8
Write-Host "  [OK] Rule file created" -ForegroundColor Green

# Done
Write-Host ""
Write-Host "========================================"
Write-Host "  Install Complete!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "Installed:"
Write-Host "  - Repo: $superpowersDir"
Write-Host "  - Link: $skillLinkPath"
Write-Host "  - Rule: $globalRulePath"
Write-Host ""
Write-Host "Usage: Restart Cursor, AI will use superpowers automatically"
Write-Host ""
Read-Host "Press Enter to exit"
