# BITS Wi-Fi Keepalive

I just found that to remain logged in at all times you just need to keep hitting the keepalive window. It resets the time you have remaining.

## Quick summary

Login/setup once, then keep this script running.
It will keep your session alive continuously (effectively "logged in forever") unless your Wi-Fi/network settings change or you switch to a different portal context.

Special credits to chrome developer tools and eyesight lol.

> Use only with your own authorized institute account/network access.

## What changed

- The script asks for your BITS username and password only once on first run.
- Credentials are saved locally at `~/.config/bits-keepalive/credentials.env` with restricted permissions.
- Next runs do not ask again unless you run reset mode.
- After setup, running the script keeps refreshing the session timer automatically.

## Option 1 — Direct Clone (Recommended)

No fork required if you just want to use it.
```bash
git clone https://github.com/aksh08022006/BitsPilaniAuthScript.git
cd BitsPilaniAuthScript
chmod +x bits_keepalive.sh
```
# Option 2 — Fork (If You Want to Contribute)

Click Fork on GitHub

Clone your fork:
```bash
git clone https://github.com/<your-username>/BitsPilaniAuthScript.git
cd BitsPilaniAuthScript
chmod +x bits_keepalive.sh
```

## How to use

Do one-time setup (login details), then run in background and forget it.

One-time setup only (save credentials and exit):

```bash
./bits_keepalive.sh --setup
```

Then start keepalive in background:

### Linux/macOS

```bash
chmod +x bits_keepalive.sh
nohup ./bits_keepalive.sh > bits_keepalive.log 2>&1 &
```

### Windows (Git Bash / WSL)

Sorry u guys don't have bash by default.

Run the script inside Git Bash or WSL and use the shell background operator so it keeps running even after you close the terminal:

```bash
chmod +x bits_keepalive.sh
./bits_keepalive.sh > bits_keepalive.log 2>&1 &
```

## Helpful commands

Reset saved credentials (if network settings change):

```bash
./bits_keepalive.sh --reset
```

Run one cycle and exit (quick test):

```bash
./bits_keepalive.sh --once
```

Stop background job later:

```bash
pkill -f bits_keepalive.sh
```
