# Oracle VM Click Checklist

Use this if you want the shortest possible Oracle setup path.

## Before You Start

1. Run:

```powershell
powershell -ExecutionPolicy Bypass -File oracle-vm-prep.ps1
```

2. Copy the public SSH key it prints.

## Oracle Console Click Path

1. Open [https://cloud.oracle.com/](https://cloud.oracle.com/)
2. Top-left menu
3. Click **Compute**
4. Click **Instances**
5. Click **Create instance**

## Fill In Exactly These Values

- **Name**: `openclaw`
- **Placement**: leave default
- **Image**:
  - click **Change image**
  - choose **Ubuntu**
  - choose **24.04**
- **Shape**:
  - click **Change shape**
  - choose **Ampere**
  - choose **VM.Standard.A1.Flex**
  - set **OCPUs** to `4`
  - set **Memory** to `24 GB`
- **Networking**:
  - keep default VCN/subnet
  - keep **Assign a public IPv4 address** enabled
- **Add SSH keys**:
  - choose **Paste public keys**
  - paste your public key
- **Boot volume**:
  - set to `50 GB`

6. Click **Create**

## After It Creates

1. Open the instance page
2. Copy the **public IP address**
3. Test SSH:

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" ubuntu@YOUR_PUBLIC_IP
```

4. If that works, run:

```powershell
powershell -ExecutionPolicy Bypass -File verify-vm-ssh.ps1
```

5. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1
```

## If Oracle Says Out Of Capacity

Retry with one of these changes:

1. choose a different availability domain
2. try `2 OCPU / 12 GB`
3. retry later
