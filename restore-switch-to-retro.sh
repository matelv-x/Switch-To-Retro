#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/pi/sg1_v4}"

fail() { echo "ERROR: $1" >&2; exit 1; }

[ -d "$APP_DIR" ] || fail "App folder not found: $APP_DIR"

if ! sudo -n true 2>/dev/null; then
  echo "This restore needs sudo because stargate files may be owned by root."
  sudo true
fi

echo "Removing Retro home redirect patch in:"
echo "  $APP_DIR"

sudo systemctl stop stargate.service || true

sudo python3 - "$APP_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

app = Path(sys.argv[1])

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

for rel in ("config/milkyway-config.json", "config/defaults-milkyway/config.json.dist"):
    path = app / rel
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
        data.pop("web_home_redirect_enabled", None)
        data.pop("web_home_redirect_page", None)
        write_json(path, data)
        print(f"Cleaned config keys: {rel}")

home_redirect = app / "web/js/home_redirect.js"
if home_redirect.exists():
    home_redirect.unlink()
    print("Removed: web/js/home_redirect.js")

index = app / "web/index.htm"
if index.exists():
    text = index.read_text(encoding="utf-8")
    text = re.sub(r"\n\s*<script src=\"/js/home_redirect\.js\"></script>", "", text)
    redirect_startup = """      $(function() {
          applyHomeRedirect(function() {
              loadDHDSymbols();
              doPoll();
          });
      });"""
    plain_startup = """      $(function() {
          loadDHDSymbols();
          doPoll();
      });"""
    text = text.replace(redirect_startup, plain_startup)
    index.write_text(text, encoding="utf-8")
    print("Cleaned: web/index.htm")

web_server = app / "classes/web_server.py"
if web_server.exists():
    text = web_server.read_text(encoding="utf-8")
    text = re.sub(
        r'\n\s*if request_path == "/dial":\n'
        r'\s*target = self\.get_home_dial_path\(\)\n'
        r'\s*query = urllib\.parse\.urlparse\(self\.path\)\.query\n'
        r'\s*self\.send_response\(302\)\n'
        r'\s*self\.send_header\("Location", target \+ \("\?" \+ query if query else ""\)\)\n'
        r'\s*self\.end_headers\(\)\n'
        r'\s*return\n',
        "\n",
        text,
        count=1,
    )
    text = re.sub(
        r'\n\n    def get_home_dial_path\(self\):\n'
        r'(?:        .*\n)+?'
        r'        return "/" \+ page\n',
        "\n",
        text,
        count=1,
    )
    web_server.write_text(text, encoding="utf-8")
    print("Cleaned: classes/web_server.py")
PY

sudo python3 -m py_compile "$APP_DIR/classes/web_server.py"
sudo find "$APP_DIR/classes" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
sudo chown -R pi:pi "$APP_DIR"
sudo systemctl start stargate.service

echo "=== SWITCH TO RETRO RESTORE COMPLETE ==="
