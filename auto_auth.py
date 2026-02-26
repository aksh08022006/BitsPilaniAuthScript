#!/usr/bin/env python3
"""Auto re-login helper for captive portal style campus firewalls.

This script checks internet connectivity at a fixed interval. If connectivity is
lost (common after captive portal session expiry), it submits stored credentials
to the configured login endpoint.

Use only with accounts you are authorized to use and in compliance with your
institution's policies.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Dict


@dataclass
class AuthConfig:
    login_url: str
    username: str
    password: str
    username_field: str = "username"
    password_field: str = "password"
    extra_fields: Dict[str, str] = field(default_factory=dict)
    check_url: str = "http://clients3.google.com/generate_204"
    timeout: int = 8
    interval: int = 60
    success_text: str | None = None
    verbose: bool = False


def parse_key_value(value: str) -> tuple[str, str]:
    if "=" not in value:
        raise argparse.ArgumentTypeError(
            f"Invalid --extra-field '{value}'. Use key=value format."
        )
    key, raw = value.split("=", 1)
    key = key.strip()
    if not key:
        raise argparse.ArgumentTypeError("extra-field key cannot be empty")
    return key, raw


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Automatically re-authenticate to a captive portal."
    )
    parser.add_argument("--login-url", required=True, help="Portal login POST URL")
    parser.add_argument(
        "--username",
        default=os.getenv("CAMPUS_AUTH_USERNAME", ""),
        help="Portal username (or set CAMPUS_AUTH_USERNAME)",
    )
    parser.add_argument(
        "--password",
        default=os.getenv("CAMPUS_AUTH_PASSWORD", ""),
        help="Portal password (or set CAMPUS_AUTH_PASSWORD)",
    )
    parser.add_argument(
        "--username-field",
        default="username",
        help="Form field name for username",
    )
    parser.add_argument(
        "--password-field",
        default="password",
        help="Form field name for password",
    )
    parser.add_argument(
        "--extra-field",
        action="append",
        default=[],
        metavar="key=value",
        help="Extra form field(s) required by your portal; can be repeated",
    )
    parser.add_argument(
        "--check-url",
        default="http://clients3.google.com/generate_204",
        help="URL used to test internet connectivity",
    )
    parser.add_argument(
        "--success-text",
        default=None,
        help="Optional text expected in login response body to mark success",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=8,
        help="HTTP timeout in seconds (default: 8)",
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=60,
        help="Check interval in seconds (default: 60)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logs",
    )
    return parser.parse_args()


def log(msg: str, verbose: bool = True) -> None:
    if verbose:
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}", flush=True)


def internet_up(check_url: str, timeout: int, verbose: bool) -> bool:
    req = urllib.request.Request(check_url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            final_url = resp.geturl()
            status = getattr(resp, "status", 200)

            # Typical connectivity checks return 204. 200 is acceptable too.
            if verbose:
                log(
                    f"Connectivity probe status={status}, final_url={final_url}",
                    verbose,
                )

            original_host = urllib.parse.urlsplit(check_url).netloc
            final_host = urllib.parse.urlsplit(final_url).netloc

            # If we got redirected to a different host, it's likely captive portal.
            if final_host and original_host and final_host != original_host:
                return False

            return status in (200, 204)
    except Exception as exc:  # network errors/timeouts
        if verbose:
            log(f"Connectivity probe failed: {exc}", verbose)
        return False


def attempt_login(config: AuthConfig) -> bool:
    form_data = {
        config.username_field: config.username,
        config.password_field: config.password,
    }
    form_data.update(config.extra_fields)

    payload = urllib.parse.urlencode(form_data).encode("utf-8")
    req = urllib.request.Request(
        config.login_url,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "CampusAutoAuth/1.0",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=config.timeout) as resp:
            status = getattr(resp, "status", 200)
            body = resp.read(8000).decode("utf-8", errors="ignore")
            if config.verbose:
                log(f"Login response status={status}", config.verbose)

            if config.success_text:
                return config.success_text in body

            # Heuristic fallback: treat 2xx as successful submission.
            return 200 <= status < 300
    except Exception as exc:
        log(f"Login attempt failed: {exc}", True)
        return False


def build_config(ns: argparse.Namespace) -> AuthConfig:
    if not ns.username or not ns.password:
        raise ValueError(
            "Missing credentials. Provide --username/--password or set "
            "CAMPUS_AUTH_USERNAME/CAMPUS_AUTH_PASSWORD"
        )

    extras: Dict[str, str] = {}
    for raw in ns.extra_field:
        key, value = parse_key_value(raw)
        extras[key] = value

    return AuthConfig(
        login_url=ns.login_url,
        username=ns.username,
        password=ns.password,
        username_field=ns.username_field,
        password_field=ns.password_field,
        extra_fields=extras,
        check_url=ns.check_url,
        timeout=ns.timeout,
        interval=ns.interval,
        success_text=ns.success_text,
        verbose=ns.verbose,
    )


def run_loop(config: AuthConfig) -> None:
    log("Auto-auth loop started.", True)
    while True:
        if internet_up(config.check_url, config.timeout, config.verbose):
            if config.verbose:
                log("Internet is active. No action needed.", config.verbose)
        else:
            log("Internet appears offline/captive. Trying portal login...", True)
            if attempt_login(config):
                log("Portal login submitted successfully.", True)
                # short cool-down before next full interval to allow route updates
                time.sleep(min(10, config.interval))
            else:
                log("Portal login may have failed. Will retry on next cycle.", True)

        time.sleep(config.interval)


def main() -> int:
    try:
        ns = parse_args()
        config = build_config(ns)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    try:
        run_loop(config)
    except KeyboardInterrupt:
        log("Stopped by user.", True)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
