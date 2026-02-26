# Campus Firewall Auto Auth Script

A lightweight Python script that automatically re-submits your campus portal credentials whenever the internet session expires.

> Use this only for your own account and only if your institution permits automation.

## What it does

- Checks internet connectivity every N seconds.
- If disconnected / redirected by captive portal, sends your login form automatically.
- Keeps running in the background.

## Requirements

- Python 3.9+
- No third-party packages required.

## Quick start

```bash
python3 auto_auth.py \
  --login-url "https://portal.example.edu/login" \
  --username "YOUR_ID" \
  --password "YOUR_PASSWORD" \
  --username-field "username" \
  --password-field "password" \
  --interval 60 \
  --verbose
```

If your portal needs extra form fields, add them with repeated `--extra-field key=value`:

```bash
python3 auto_auth.py \
  --login-url "https://portal.example.edu/login" \
  --username "YOUR_ID" \
  --password "YOUR_PASSWORD" \
  --extra-field "mode=191" \
  --extra-field "producttype=0"
```

## Safer credential handling

Instead of plain command history, use environment variables:

```bash
export CAMPUS_AUTH_USERNAME="YOUR_ID"
export CAMPUS_AUTH_PASSWORD="YOUR_PASSWORD"

python3 auto_auth.py --login-url "https://portal.example.edu/login"
```

## How to find correct form fields

1. Open the portal login page in browser.
2. Press **F12** → **Network**.
3. Perform one manual login.
4. Inspect the login request payload and copy:
   - POST URL (`--login-url`)
   - Username field name (`--username-field`)
   - Password field name (`--password-field`)
   - Any required fixed fields (`--extra-field`)

## Keep it running after reboot (Linux, systemd user service)

Create `~/.config/systemd/user/campus-auth.service`:

```ini
[Unit]
Description=Campus Auto Auth
After=network-online.target

[Service]
Type=simple
Environment=CAMPUS_AUTH_USERNAME=YOUR_ID
Environment=CAMPUS_AUTH_PASSWORD=YOUR_PASSWORD
ExecStart=/usr/bin/python3 /absolute/path/to/auto_auth.py --login-url https://portal.example.edu/login --interval 60
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Then run:

```bash
systemctl --user daemon-reload
systemctl --user enable --now campus-auth.service
systemctl --user status campus-auth.service
```

## Notes

- Captive portals vary by vendor, so exact field names differ.
- If your portal has CAPTCHA / OTP / MFA, full automation may not be possible.
