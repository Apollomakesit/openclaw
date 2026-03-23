# Verify Oracle VM SSH connectivity before deployment.

$ErrorActionPreference = "Stop"

function Prompt-Required {
    param([string]$Label, [string]$Default = "")
    while ($true) {
        if ($Default) {
            $value = Read-Host "$Label [$Default]"
            if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
            return $value.Trim()
        }
        $value = Read-Host $Label
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
        Write-Host "This field is required." -ForegroundColor Yellow
    }
}

Write-Host "" 
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Oracle VM SSH Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$defaultKey = "$env:USERPROFILE\.ssh\id_ed25519"
$hostName = Prompt-Required -Label "Oracle VM public IP or DNS name"
$userName = Prompt-Required -Label "SSH username" -Default "ubuntu"
$keyPath = Prompt-Required -Label "Path to SSH private key" -Default $defaultKey

if (-not (Test-Path $keyPath)) {
    Write-Host "SSH key not found: $keyPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing raw SSH connection..." -ForegroundColor Green
& ssh -i $keyPath -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$userName@$hostName" "echo SSH_OK && uname -m && whoami"
if ($LASTEXITCODE -ne 0) {
    Write-Host "SSH failed. Check the VM IP, username, key, and Oracle ingress rules." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing sudo and basic package manager access..." -ForegroundColor Green
& ssh -i $keyPath -o StrictHostKeyChecking=accept-new "$userName@$hostName" "command -v sudo >/dev/null 2>&1 && command -v apt >/dev/null 2>&1 && echo VM_READY"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Connected, but the VM does not look like the expected Ubuntu image." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "VM is reachable and looks ready for deployment." -ForegroundColor Green
Write-Host "Next command:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1"
Write-Host ""
