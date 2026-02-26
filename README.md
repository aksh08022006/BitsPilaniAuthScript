# Campus Firewall Auto Auth Script

A reusable Python script for students to automatically re-authenticate on a campus captive portal/firewall when sessions expire.


## 1) What this solves

Many campus networks expire sessions every few minutes/hours. This script:

- checks internet reachability periodically,
- detects probable captive-portal interruption,
- resubmits your login form automatically,
- verifies post-login connectivity.

File: `auto_auth.py` (no third-party dependencies).

---

## 2) Requirements

- Python 3.9+ installed
- Portal login details known:
  - login POST URL
  - username field name
  - password field name
  - any extra required hidden fields

---

## 3) First-time setup (for any student)

### Step A: Get your portal request details

1. Open portal login page.
2. Press **F12** → **Network** tab.
3. Login manually once.
4. Open the login request and copy:
   - **Request URL** → `--login-url`
   - form username key → `--username-field`
   - form password key → `--password-field`
   - any fixed fields (e.g. mode/producttype) → `--extra-field key=value`

### Step B: Set credentials safely

Prefer environment variables over plain command history:

```bash
export CAMPUS_AUTH_USERNAME="YOUR_ID"
export CAMPUS_AUTH_PASSWORD="YOUR_PASSWORD"
```

### Step C: Validate setup once

Run one full test cycle and exit:

```bash
python3 auto_auth.py \
  --login-url "https://portal.example.edu/login" \
  --username-field "username" \
  --password-field "password" \
  --extra-field "mode=191" \
  --run-once \
  --force-login \
  --verbose
```

If this returns exit code `0`, setup is likely correct.

---

## 4) How to check if it is working

Use these indicators:

1. **Run-once validation mode** (`--run-once --force-login --verbose`) should print:
   - login submission attempted,
   - post-login connectivity check passed.
2. **Exit codes**:
   - `0` = success / no action needed / verified connectivity,
   - `1` = login attempted but connectivity still not confirmed,
   - `2` = configuration/argument error.
3. **Live loop logs** (`--verbose`) should show periodic checks and re-login attempts only when needed.

Quick live run:

```bash
python3 auto_auth.py \
  --login-url "https://portal.example.edu/login" \
  --interval 60 \
  --verbose
```

---

## 5) Command reference

```text
required:
  --login-url URL

credentials:
  --username USERNAME           (or CAMPUS_AUTH_USERNAME)
  --password PASSWORD           (or CAMPUS_AUTH_PASSWORD)

portal fields:
  --username-field NAME         (default: username)
  --password-field NAME         (default: password)
  --extra-field key=value       (repeatable)

network behavior:
  --check-url URL               (default: http://clients3.google.com/generate_204)
  --timeout SEC                 (default: 8)
  --interval SEC                (default: 60)
  --success-text TEXT           (optional body marker for successful login)

modes:
  --run-once                    run one cycle and exit
  --force-login                 attempt login even if connectivity appears up
  --verbose                     detailed logs
```

---

## 6) Recommended reusable rollout for college students

- Share this repository plus a **template command** in your student groups.
- Keep campus-specific defaults documented (field names, extra fields).
- Ask each student to set personal credentials via env vars.
- For Linux users, provide a systemd user service template (below).

### Optional: Linux autostart via systemd (user mode)

Create `~/.config/systemd/user/campus-auth.service`:

```ini
[Unit]
Description=Campus Auto Auth
After=network-online.target

[Service]
Type=simple
Environment=CAMPUS_AUTH_USERNAME=YOUR_ID
Environment=CAMPUS_AUTH_PASSWORD=YOUR_PASSWORD
ExecStart=/usr/bin/python3 /absolute/path/to/auto_auth.py --login-url https://portal.example.edu/login --interval 60 --verbose
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Enable:

```bash
systemctl --user daemon-reload
systemctl --user enable --now campus-auth.service
systemctl --user status campus-auth.service
```

---

## 7) Troubleshooting

- **Login returns success but net still not working**:
  - verify `--login-url` and field names,
  - add missing `--extra-field` values,
  - set `--success-text` if portal gives clear success message.
- **Works manually but not in script**:
  - compare exact browser payload with script arguments.
- **Portal has CAPTCHA/OTP/MFA**:
  - full automation may not be possible.

---

## 8) Security notes

- Never commit personal credentials.
- Avoid sharing shell history with plaintext passwords.
- Use per-user env vars or OS credential tools where possible.
