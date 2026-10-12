"""Health-gated local Docker blue/green switch. Does not change Vercel aliases."""
import argparse
import json
from pathlib import Path
import subprocess
import urllib.request
import time

ROOT = Path(__file__).resolve().parent
COMPOSE = ["docker", "compose", "--env-file", str(ROOT / ".env"), "-f", str(ROOT / "compose.yaml")]


def health(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=10) as response:
        return json.load(response)


def switch(color):
    expected = health(8081 if color == "blue" else 8082)
    if expected.get("status") != "ok" or expected.get("color") != color:
        raise RuntimeError("Candidate did not pass readiness checks")
    if color == "green" and expected.get("auth_mode") not in {"hybrid", "google"}:
        raise RuntimeError("Green must have Google auth enabled")
    command = f"""set -eu
cp /etc/nginx/conf.d/default.conf /tmp/wwtd-previous.conf
cp /routes/{color}.conf /etc/nginx/conf.d/default.conf
if ! nginx -t; then
  cp /tmp/wwtd-previous.conf /etc/nginx/conf.d/default.conf
  exit 1
fi
nginx -s reload
"""
    subprocess.run(COMPOSE + ["exec", "-T", "proxy", "sh", "-c", command], check=True)
    try:
        for _ in range(10):
            actual = health(8080)
            if actual.get("color") == color:
                print(f"Traffic now routes to {color} ({actual['auth_mode']}).")
                return
            time.sleep(0.5)
        raise RuntimeError("Proxy did not route to the requested release")
    except Exception:
        subprocess.run(COMPOSE + ["exec", "-T", "proxy", "sh", "-c",
            "cp /tmp/wwtd-previous.conf /etc/nginx/conf.d/default.conf && nginx -t && nginx -s reload"], check=True)
        raise RuntimeError("Switch failed; previous routing configuration restored")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("color", choices=["blue", "green"])
    switch(parser.parse_args().color)
