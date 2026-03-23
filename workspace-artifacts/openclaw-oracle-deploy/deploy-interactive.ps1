# OpenClaw Oracle A1 Interactive Deployment Script (Windows 10)
# Run: Right-click > Run with PowerShell, or from a terminal: powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1

$ErrorActionPreference = "Stop"

$presetPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "bundle-presets.ps1"
if (Test-Path $presetPath) {
    . $presetPath
}

$defaultOpenRouterModel = if ($PresetOpenRouterModel) { $PresetOpenRouterModel } else { "" }
$defaultWhatsAppPolicy = if ($PresetWhatsAppPolicy) { $PresetWhatsAppPolicy } else { "allowlist" }
$defaultWhatsAppNumber = if ($PresetWhatsAppNumber) { $PresetWhatsAppNumber } else { "" }
$defaultEnableWhatsApp = if ($null -ne $PresetEnableWhatsApp) { [bool]$PresetEnableWhatsApp } else { $true }
$defaultEnableLanceDb = if ($null -ne $PresetEnableLanceDb) { [bool]$PresetEnableLanceDb } else { $false }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " OpenClaw Oracle A1 Deployment" -ForegroundColor Cyan
Write-Host " Interactive Setup for Windows 10" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------

function Prompt-Required {
    param([string]$Label, [string]$Help, [string]$Default)
    while ($true) {
        if ($Help) { Write-Host "  $Help" -ForegroundColor DarkGray }
        if ($Default) {
            $input = Read-Host "$Label [$Default]"
            if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
            return $input.Trim()
        }
        $input = Read-Host "$Label"
        if (-not [string]::IsNullOrWhiteSpace($input)) { return $input.Trim() }
        Write-Host "  This field is required." -ForegroundColor Yellow
    }
}

function Prompt-Secret {
    param([string]$Label, [string]$Help)
    while ($true) {
        if ($Help) { Write-Host "  $Help" -ForegroundColor DarkGray }
        $secure = Read-Host "$Label" -AsSecureString
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        if (-not [string]::IsNullOrWhiteSpace($plain)) { return $plain.Trim() }
        Write-Host "  This field is required." -ForegroundColor Yellow
    }
}

function Prompt-YesNo {
    param([string]$Label, [bool]$Default = $false)
    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $input = Read-Host "$Label $hint"
    if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
    return ($input.Trim().ToLower() -eq "y")
}

function Prompt-Optional {
    param([string]$Label, [string]$Help, [string]$Default)
    if ($Help) { Write-Host "  $Help" -ForegroundColor DarkGray }
    if ($Default) {
        $input = Read-Host "$Label [$Default]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        return $input.Trim()
    }
    $input = Read-Host "$Label (press Enter to skip)"
    if ([string]::IsNullOrWhiteSpace($input)) { return "" }
    return $input.Trim()
}

function Prompt-Choice {
    param([string]$Label, [string[]]$Choices, [string]$Default)
    Write-Host $Label -ForegroundColor Green
    for ($i = 0; $i -lt $Choices.Length; $i++) {
        $index = $i + 1
        $marker = if ($Choices[$i] -eq $Default) { " (default)" } else { "" }
        Write-Host "  $index. $($Choices[$i])$marker" -ForegroundColor DarkGray
    }
    while ($true) {
        $selection = Read-Host "Choose 1-$($Choices.Length)"
        if ([string]::IsNullOrWhiteSpace($selection) -and $Default) {
            return $Default
        }
        $parsed = 0
        if ([int]::TryParse($selection, [ref]$parsed)) {
            if ($parsed -ge 1 -and $parsed -le $Choices.Length) {
                return $Choices[$parsed - 1]
            }
        }
        Write-Host "  Enter a number from the list." -ForegroundColor Yellow
    }
}

# -------------------------------------------------------------------
# Step 1: Oracle VM connection
# -------------------------------------------------------------------

Write-Host "--- Step 1: Oracle VM Connection ---" -ForegroundColor Green
Write-Host ""

$oracleHost = Prompt-Required -Label "Oracle VM public IP address" `
    -Help "The public IP shown after creating your VM in OCI Console."

$oracleUser = Prompt-Required -Label "SSH username" `
    -Help "Usually 'ubuntu' for Ubuntu images." `
    -Default "ubuntu"

$sshKey = Prompt-Required -Label "Path to your SSH private key" `
    -Help "Example: C:\Users\you\.ssh\id_ed25519" `
    -Default "$env:USERPROFILE\.ssh\id_ed25519"

if (-not (Test-Path $sshKey)) {
    Write-Host "WARNING: SSH key not found at $sshKey" -ForegroundColor Yellow
    Write-Host "  The script will still generate the files but SSH will fail." -ForegroundColor Yellow
    Write-Host ""
}

# -------------------------------------------------------------------
# Step 2: Tailscale
# -------------------------------------------------------------------

Write-Host ""
Write-Host "--- Step 2: Tailscale ---" -ForegroundColor Green
Write-Host "  Create a reusable auth key at https://login.tailscale.com/admin/settings/keys" -ForegroundColor DarkGray
Write-Host ""

$tailscaleKey = Prompt-Secret -Label "Tailscale auth key" `
    -Help "Starts with tskey-auth-..."

$tailscaleHostname = Prompt-Required -Label "Tailscale hostname for this machine" `
    -Default "openclaw"

# -------------------------------------------------------------------
# Step 3: OpenRouter
# -------------------------------------------------------------------

Write-Host ""
Write-Host "--- Step 3: OpenRouter ---" -ForegroundColor Green
Write-Host "  Get your API key from https://openrouter.ai/keys" -ForegroundColor DarkGray
Write-Host "  Find the exact model slug from https://openrouter.ai/models" -ForegroundColor DarkGray
Write-Host ""

$openRouterKey = Prompt-Secret -Label "OpenRouter API key" `
    -Help "Starts with sk-or-..."

Write-Host ""
Write-Host "  For Nemotron 3 Super (free), go to https://openrouter.ai/models" -ForegroundColor DarkGray
Write-Host "  and search for 'Nemotron'. Copy the exact model ID shown on the page." -ForegroundColor DarkGray
Write-Host "  The format in OpenClaw is: openrouter/<provider>/<model>" -ForegroundColor DarkGray
Write-Host "  Example: openrouter/nvidia/llama-3.3-nemotron-super-49b-v1:free" -ForegroundColor DarkGray
Write-Host ""

$openRouterModel = Prompt-Required -Label "OpenRouter model ref" `
    -Help "Paste the exact slug from OpenRouter, prefixed with openrouter/" `
    -Default $defaultOpenRouterModel

if (-not $openRouterModel.StartsWith("openrouter/")) {
    $openRouterModel = "openrouter/$openRouterModel"
    Write-Host "  Auto-prefixed to: $openRouterModel" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------
# Step 4: WhatsApp
# -------------------------------------------------------------------

Write-Host ""
Write-Host "--- Step 4: WhatsApp Channel ---" -ForegroundColor Green
Write-Host ""

$enableWhatsApp = Prompt-YesNo -Label "Enable WhatsApp channel?" -Default $defaultEnableWhatsApp

$whatsAppNumber = ""
$whatsAppDmPolicy = "pairing"

if ($enableWhatsApp) {
    Write-Host ""
    Write-Host "  WhatsApp uses QR code linking (WhatsApp Web)." -ForegroundColor DarkGray
    Write-Host "  After deployment, you will scan a QR code from the gateway." -ForegroundColor DarkGray
    Write-Host ""

    $policyChoice = Prompt-Choice -Label "Choose your WhatsApp inbound policy:" `
        -Choices @("allowlist", "pairing") `
        -Default $defaultWhatsAppPolicy

    $whatsAppDmPolicy = $policyChoice

    if ($whatsAppDmPolicy -eq "allowlist") {
        $whatsAppNumber = Prompt-Required -Label "Your phone number (E.164 format, e.g. +15551234567)" `
            -Help "Only this number will be allowed to message the bot." `
            -Default $defaultWhatsAppNumber
    } else {
        $whatsAppNumber = Prompt-Optional -Label "Optional phone number for later allowlist use" `
            -Help "Leave blank if you want pairing mode only." `
            -Default $defaultWhatsAppNumber
        Write-Host "  Pairing mode enabled. First sender must be manually approved." -ForegroundColor DarkGray
    }
}

# -------------------------------------------------------------------
# Step 5: Memory
# -------------------------------------------------------------------

Write-Host ""
Write-Host "--- Step 5: Memory (learn from mistakes, grow over time) ---" -ForegroundColor Green
Write-Host ""
Write-Host "  Recommended: LanceDB auto-capture + auto-recall" -ForegroundColor DarkGray
Write-Host "  This is the strongest memory mode in this bundle." -ForegroundColor DarkGray
Write-Host "  It needs a separate embeddings API key. Your OpenRouter key is not enough for memory embeddings." -ForegroundColor DarkGray
Write-Host ""

$enableLanceDb = Prompt-YesNo -Label "Use LanceDB memory with auto-capture and auto-recall?" -Default $defaultEnableLanceDb

$memoryApiKey = ""
$memoryModel = "text-embedding-3-small"
$memoryBaseUrl = ""
$memoryDimensions = ""

if ($enableLanceDb) {
    Write-Host ""
    Write-Host "  Memory embeddings provider options:" -ForegroundColor DarkGray
    Write-Host "  - easiest: OpenAI with text-embedding-3-small" -ForegroundColor DarkGray
    Write-Host "  - advanced: any OpenAI-compatible embeddings endpoint" -ForegroundColor DarkGray
    Write-Host "" 
    $memoryApiKey = Prompt-Secret -Label "Embeddings API key" `
        -Help "Required for LanceDB memory. This is separate from your OpenRouter API key."

    $memoryModel = Prompt-Required -Label "Embedding model" `
        -Default "text-embedding-3-small"

    $memoryBaseUrl = Prompt-Optional -Label "Custom embeddings base URL" `
        -Help "Leave blank for OpenAI. Set this only if you use a different OpenAI-compatible embeddings service."

    $memoryDimensions = Prompt-Optional -Label "Vector dimensions" `
        -Help "Leave blank for standard models like text-embedding-3-small."
}

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Oracle VM:     $oracleUser@$oracleHost"
Write-Host "  SSH key:       $sshKey"
Write-Host "  Tailscale:     $tailscaleHostname"
Write-Host "  Model:         $openRouterModel"
Write-Host "  WhatsApp:      $(if ($enableWhatsApp) { 'Yes' } else { 'No' })"
if ($enableWhatsApp -and $whatsAppNumber) {
    Write-Host "  WhatsApp num:  $whatsAppNumber"
}
Write-Host "  LanceDB mem:   $(if ($enableLanceDb) { 'Yes (strongest mode)' } else { 'No (free local)' })"
Write-Host ""

$proceed = Prompt-YesNo -Label "Deploy now?" -Default $true
if (-not $proceed) {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

# -------------------------------------------------------------------
# Write deploy.env
# -------------------------------------------------------------------

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir "deploy.env"

$envContent = @"
ORACLE_HOST=$oracleHost
ORACLE_USER=$oracleUser
SSH_PRIVATE_KEY=$sshKey
TAILSCALE_AUTHKEY=$tailscaleKey
TAILSCALE_HOSTNAME=$tailscaleHostname
OPENCLAW_HOSTNAME=$tailscaleHostname
OPENROUTER_API_KEY=$openRouterKey
OPENROUTER_MODEL=$openRouterModel
ENABLE_WHATSAPP=$(if ($enableWhatsApp) { '1' } else { '0' })
WHATSAPP_DM_POLICY=$whatsAppDmPolicy
WHATSAPP_ALLOW_FROM=$whatsAppNumber
ENABLE_MEMORY_LANCEDB=$(if ($enableLanceDb) { '1' } else { '0' })
MEMORY_EMBEDDINGS_API_KEY=$memoryApiKey
MEMORY_EMBEDDINGS_MODEL=$memoryModel
MEMORY_EMBEDDINGS_BASE_URL=$memoryBaseUrl
MEMORY_EMBEDDINGS_DIMENSIONS=$memoryDimensions
MEMORY_CAPTURE_MAX_CHARS=500
"@

Set-Content -Path $envFile -Value $envContent -Encoding UTF8
Write-Host "Wrote $envFile" -ForegroundColor DarkGray

# -------------------------------------------------------------------
# Upload and run
# -------------------------------------------------------------------

Write-Host ""
Write-Host "Uploading deployment bundle to $oracleUser@$oracleHost..." -ForegroundColor Green

$remoteDir = "~/openclaw-oracle-deploy"

# Create remote directory
& ssh -i $sshKey -o StrictHostKeyChecking=accept-new "$oracleUser@$oracleHost" "mkdir -p $remoteDir"
if ($LASTEXITCODE -ne 0) { Write-Host "SSH connection failed." -ForegroundColor Red; exit 1 }

# Upload files
$filesToUpload = @(
    (Join-Path $scriptDir "remote-bootstrap.sh"),
    (Join-Path $scriptDir "render-config.mjs"),
    $envFile
)

foreach ($f in $filesToUpload) {
    & scp -i $sshKey -o StrictHostKeyChecking=accept-new $f "${oracleUser}@${oracleHost}:${remoteDir}/"
    if ($LASTEXITCODE -ne 0) { Write-Host "Upload failed: $f" -ForegroundColor Red; exit 1 }
}

Write-Host "Running remote bootstrap..." -ForegroundColor Green
& ssh -i $sshKey -o StrictHostKeyChecking=accept-new "$oracleUser@$oracleHost" "cd $remoteDir && chmod +x remote-bootstrap.sh && bash ./remote-bootstrap.sh ./deploy.env"
if ($LASTEXITCODE -ne 0) { Write-Host "Remote bootstrap failed." -ForegroundColor Red; exit 1 }

# -------------------------------------------------------------------
# WhatsApp QR linking instructions
# -------------------------------------------------------------------

if ($enableWhatsApp) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " WhatsApp QR Linking" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  The gateway is running. Now link WhatsApp:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  1. SSH into the VM:" -ForegroundColor White
    Write-Host "     ssh -i `"$sshKey`" $oracleUser@$oracleHost" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Run the WhatsApp login command:" -ForegroundColor White
    Write-Host "     openclaw channels login --channel whatsapp" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. A QR code will appear in the terminal." -ForegroundColor White
    Write-Host "     Open WhatsApp on your phone > Settings > Linked Devices > Link a Device" -ForegroundColor White
    Write-Host "     Scan the QR code." -ForegroundColor White
    Write-Host ""
    if ($whatsAppDmPolicy -eq "pairing") {
        Write-Host "  4. Since you are using pairing mode, approve your first message:" -ForegroundColor White
        Write-Host "     openclaw pairing list whatsapp" -ForegroundColor Yellow
        Write-Host "     openclaw pairing approve whatsapp <CODE>" -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "  After linking, send a WhatsApp message to the linked number and" -ForegroundColor White
    Write-Host "  OpenClaw will respond using your OpenRouter model." -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Deployment Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Green
Write-Host "  1. Lock down Oracle VCN to Tailscale-only (UDP 41641)" -ForegroundColor White
Write-Host "  2. Access Control UI: https://$tailscaleHostname.<tailnet>.ts.net/" -ForegroundColor White
if ($enableWhatsApp) {
    Write-Host "  3. Link WhatsApp using the commands above" -ForegroundColor White
}
Write-Host ""
