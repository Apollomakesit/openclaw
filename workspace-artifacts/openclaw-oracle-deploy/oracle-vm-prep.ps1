# Oracle VM Preflight Helper for Windows 10
# Run before deploy-interactive.ps1 if you need help creating the Oracle VM.

$ErrorActionPreference = "Stop"

function Ask-YesNo {
    param([string]$Label, [bool]$Default = $true)
    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$Label $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim().ToLower() -eq "y"
}

function Ensure-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required command not found: $Name"
    }
}

Write-Host "" 
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Oracle VM Prep Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    Ensure-Command ssh
    Ensure-Command ssh-keygen
    Write-Host "OpenSSH tools found." -ForegroundColor Green
} catch {
    Write-Host "OpenSSH Client is missing on this Windows machine." -ForegroundColor Red
    Write-Host "Install it from: Settings > Apps > Optional features > Add feature > OpenSSH Client" -ForegroundColor Yellow
    exit 1
}

$sshDir = Join-Path $env:USERPROFILE ".ssh"
$privateKey = Join-Path $sshDir "id_ed25519"
$publicKey = "$privateKey.pub"

if (-not (Test-Path $privateKey)) {
    if (Ask-YesNo "No SSH key found at $privateKey. Generate one now?" $true) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
        & ssh-keygen -t ed25519 -C "openclaw-oracle" -f $privateKey
    } else {
        Write-Host "You need an SSH key before creating the VM." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "SSH key found at $privateKey" -ForegroundColor Green
}

Write-Host ""
Write-Host "Your public key is:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Get-Content $publicKey
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

if (Ask-YesNo "Open the Oracle Cloud signup page in your browser?" $true) {
    Start-Process "https://www.oracle.com/cloud/free/"
}

if (Ask-YesNo "Open the Oracle Cloud console in your browser?" $true) {
    Start-Process "https://cloud.oracle.com/"
}

if (Ask-YesNo "Open the step-by-step VM guide in Notepad?" $true) {
    $guidePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "oracle-vm-setup.md"
    Start-Process notepad.exe $guidePath
}

Write-Host ""
Write-Host "Use these exact VM settings:" -ForegroundColor Cyan
Write-Host "  Name:        openclaw"
Write-Host "  Image:       Ubuntu 24.04"
Write-Host "  Shape:       VM.Standard.A1.Flex"
Write-Host "  OCPUs:       4"
Write-Host "  Memory:      24 GB"
Write-Host "  Boot volume: 50 GB"
Write-Host "  User:        ubuntu"
Write-Host ""
Write-Host "When the VM is created, test SSH with:" -ForegroundColor Cyan
Write-Host "  ssh -i \"$privateKey\" ubuntu@YOUR_PUBLIC_IP"
Write-Host ""
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1"
Write-Host ""
