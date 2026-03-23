# Oracle VM Setup For Windows 10

Use this before running `deploy-interactive.ps1`.

## Goal

Create an Oracle Cloud Always Free ARM VM that is ready for the OpenClaw deployment bundle.

Target VM settings:

- image: `Ubuntu 24.04`
- architecture: `aarch64`
- shape: `VM.Standard.A1.Flex`
- OCPUs: `4`
- memory: `24 GB`
- boot volume: `50 GB` or more

## Part 1: Prepare Windows

Open **PowerShell** and verify SSH is installed:

```powershell
ssh -V
ssh-keygen -V
```

If `ssh` is missing:

1. Open **Settings**
2. Go to **Apps > Optional features**
3. Install **OpenSSH Client**

Create an SSH key if you do not already have one:

```powershell
ssh-keygen -t ed25519 -C "openclaw-oracle"
```

Accept the default path:

```text
C:\Users\YOUR_NAME\.ssh\id_ed25519
```

Show your public key:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

You will paste that public key into Oracle when creating the VM.

## Part 2: Create The Oracle VM

1. Sign in to [https://cloud.oracle.com/](https://cloud.oracle.com/)
2. In the top-left menu, open **Compute > Instances**
3. Click **Create instance**

Fill in these values:

- **Name**: `openclaw`
- **Placement**: leave default unless capacity fails
- **Image and shape**:
  - click **Change image**
  - choose `Ubuntu`
  - choose `24.04`
  - confirm it is **Ampere / Arm / aarch64** compatible
- **Shape**:
  - click **Change shape**
  - choose `Ampere`
  - choose `VM.Standard.A1.Flex`
  - set `4` OCPUs
  - set `24 GB` memory
- **Networking**:
  - leave the default VCN/subnet unless you already know OCI networking
  - allow Oracle to assign a **public IPv4 address**
- **Add SSH keys**:
  - choose **Paste public keys**
  - paste the output of:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

- **Boot volume**:
  - set to `50 GB` or larger

Then click **Create**.

## Part 3: If Oracle Says Out Of Capacity

This is common on the free A1 tier.

Try these in order:

1. retry in a different **availability domain**
2. reduce to `2 OCPU / 12 GB` temporarily, then resize later if possible
3. retry at a different time of day
4. try a different region if your account allows it

## Part 4: Get The VM IP Address

After the VM finishes provisioning:

1. open the instance page
2. copy the **public IP address**

Test SSH from PowerShell:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

If you get a host key prompt, answer `yes`.

If you see a Linux shell prompt, the VM is ready.

## Part 5: Run The OpenClaw Deployment

Now go back to the bundle folder and run:

```powershell
cd C:\path\to\openclaw-oracle-deploy
powershell -ExecutionPolicy Bypass -File deploy-interactive.ps1
```

Use:

- `ORACLE_HOST`: your VM public IP
- `ORACLE_USER`: `ubuntu`
- `SSH key path`: `C:\Users\YOUR_NAME\.ssh\id_ed25519`

## Part 6: Lock Down Oracle After Install

After the deployment finishes and Tailscale is working:

1. Go to **Networking > Virtual Cloud Networks**
2. Open your VM's VCN
3. Open **Security Lists**
4. Edit the default ingress rules
5. Remove everything except:
   - `0.0.0.0/0 UDP 41641`

That keeps Tailscale working and blocks normal public access.

## Troubleshooting

### SSH times out

Check:

1. the VM has a public IP
2. your SSH public key was pasted correctly
3. the default ingress rule still allows TCP 22 during first setup

### SSH says permission denied

Make sure you are using the matching private key:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

### VM was created with the wrong shape

Delete it and recreate it. For this use case, `VM.Standard.A1.Flex` is the right target.

### You do not know which values to pick in Oracle

Use exactly the values listed in **Part 2** above. Do not customize networking or boot options unless you already understand OCI.
