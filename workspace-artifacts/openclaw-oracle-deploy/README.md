# Start Here

This bundle is for **Windows 10** and gives you one path from zero to OpenClaw on Oracle Cloud with WhatsApp.

It is already configured for:

- OpenRouter model: `openrouter/nvidia/nemotron-3-super-120b-a12b:free`
- WhatsApp policy: `allowlist`
- WhatsApp allowed number: `+40769655124`
- Memory mode: `memory-lancedb` with auto-capture and auto-recall enabled by default

## What You Need Before You Start

You will be prompted for these during setup:

1. Oracle Cloud account
2. Tailscale auth key
3. OpenRouter API key
4. Embeddings API key for memory

Important: the memory embeddings key is separate from your OpenRouter API key.

## The Only Path To Follow

### Step 1

Open PowerShell in this folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File oracle-vm-prep.ps1
```

### Step 2

Follow this checklist exactly to create the Oracle VM:

[workspace-artifacts/openclaw-oracle-deploy/oracle-vm-click-checklist.md](workspace-artifacts/openclaw-oracle-deploy/oracle-vm-click-checklist.md)

Use these VM settings:

- Shape: `VM.Standard.A1.Flex`
- OCPUs: `4`
- RAM: `24 GB`
- Image: `Ubuntu 24.04 aarch64`
- Boot volume: `50 GB`
- Username: `ubuntu`

### Step 3

After the VM is created and you have its public IP, verify SSH works:

```powershell
powershell -ExecutionPolicy Bypass -File verify-vm-ssh.ps1
```

### Step 4

Run the full deployment wizard:

```powershell
powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1
```

It will ask for:

1. Oracle VM IP
2. SSH key path
3. Tailscale auth key
4. OpenRouter API key
5. Embeddings API key for memory

The OpenRouter model and WhatsApp number are already prefilled.

### Step 5

After deployment finishes, link WhatsApp by QR:

```bash
openclaw channels login --channel whatsapp
```

On your phone:

1. open WhatsApp
2. go to **Settings > Linked Devices**
3. tap **Link a Device**
4. scan the QR code shown in the terminal

### Step 6

Lock down Oracle networking:

1. open Oracle Cloud Console
2. go to **Networking > Virtual Cloud Networks**
3. open your VM's VCN
4. open **Security Lists**
5. edit the ingress rules
6. remove everything except `0.0.0.0/0 UDP 41641`

## What This Bundle Does

The scripts install and configure:

- OpenClaw Gateway
- WhatsApp channel plugin
- `memory-lancedb`
- Tailscale Serve
- your OpenRouter model
- your WhatsApp allowlist number

## Files You Will Use

Use only these files in this order:

1. [workspace-artifacts/openclaw-oracle-deploy/oracle-vm-prep.ps1](workspace-artifacts/openclaw-oracle-deploy/oracle-vm-prep.ps1)
2. [workspace-artifacts/openclaw-oracle-deploy/oracle-vm-click-checklist.md](workspace-artifacts/openclaw-oracle-deploy/oracle-vm-click-checklist.md)
3. [workspace-artifacts/openclaw-oracle-deploy/verify-vm-ssh.ps1](workspace-artifacts/openclaw-oracle-deploy/verify-vm-ssh.ps1)
4. [workspace-artifacts/openclaw-oracle-deploy/deploy-interactive.ps1](workspace-artifacts/openclaw-oracle-deploy/deploy-interactive.ps1)

## Important Notes

- This bundle targets OpenClaw on Oracle A1 ARM.
- Re-running deployment overwrites `~/.openclaw/openclaw.json` after creating a timestamped backup.
- WhatsApp will only accept messages from `+40769655124` by default.
- The strongest memory mode in this bundle requires an embeddings API key.
