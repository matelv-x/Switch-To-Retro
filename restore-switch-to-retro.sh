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

if [ "${STARGATE_ADDON_NO_RESTART:-0}" != "1" ]; then
  sudo systemctl stop stargate.service || true
fi

sudo python3 - "$APP_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

app = Path(sys.argv[1])
fan113_installed = (
    (app / ".fan113-home-addon/state.json").is_file()
    and (app / "web/js/fan113_home_config.js").is_file()
)

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

def latest_backup(path):
    matches = sorted(
        path.parent.glob(path.name + ".bak-retro-*"),
        key=lambda item: item.stat().st_mtime_ns,
        reverse=True,
    )
    return matches[0] if matches else None

def contains_fan113(value):
    if not isinstance(value, dict):
        return False
    return (
        value.get("value") == "fan113.html"
        or "fan113.html" in value.get("enum_values", [])
    )

for rel in ("config/milkyway-config.json", "config/defaults-milkyway/config.json.dist"):
    path = app / rel
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
        backup = latest_backup(path)
        prior = json.loads(backup.read_text(encoding="utf-8")) if backup else {}
        for key in ("web_home_redirect_enabled", "web_home_redirect_page"):
            current = data.get(key)
            owned = isinstance(current, dict) and (
                "stargate.local" in str(current.get("desc", ""))
                or "retro dialing page" in str(current.get("desc", ""))
                or (
                    not fan113_installed
                    and current.get("display_name") in (
                        "Home Redirect Enabled",
                        "Home Page",
                    )
                )
            )
            prior_value = prior.get(key)
            prior_owned = isinstance(prior_value, dict) and (
                "stargate.local" in str(prior_value.get("desc", ""))
                or "retro dialing page" in str(prior_value.get("desc", ""))
                or (
                    not fan113_installed
                    and prior_value.get("display_name") in (
                        "Home Redirect Enabled",
                        "Home Page",
                    )
                )
            )
            if contains_fan113(prior_value) and not fan113_installed:
                # A stale backup from a previously removed FAN113 Home add-on
                # must never reactivate that page during Switch To Retro removal.
                prior_owned = True
            if key in prior and owned and not prior_owned:
                data[key] = prior[key]
            elif owned:
                data.pop(key, None)
        if not fan113_installed:
            page = data.get("web_home_redirect_page")
            if isinstance(page, dict):
                page["enum_values"] = [
                    value for value in page.get("enum_values", [])
                    if value != "fan113.html"
                ]
                if page.get("value") == "fan113.html":
                    page["value"] = "retro/dial.html"
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

address_book = app / "web/js/address_book.js"
if address_book.exists():
    text = address_book.read_text(encoding="utf-8")
    backup = latest_backup(address_book)
    replacement = "window.location = \\'index.htm?address="
    if backup:
        prior = backup.read_text(encoding="utf-8")
        for candidate in (
            "window.location = \\'index.htm?address=",
            "window.location = \\'/dial?address=",
            "window.location = \\'/stargate/dial?address=",
        ):
            if candidate in prior:
                replacement = candidate
                break
    text = text.replace("window.location = \\'/stargate/dial?address=", replacement)
    address_book.write_text(text, encoding="utf-8")
    print("Cleaned: web/js/address_book.js")

retro_nav = app / "web/retro/js/navigation.js"
if retro_nav.exists():
    text = retro_nav.read_text(encoding="utf-8")
    owned = '        <a href="/">Home</a>'
    backup = latest_backup(retro_nav)
    prior = None
    if backup:
        for line in backup.read_text(encoding="utf-8").splitlines():
            if ">Home</a>" in line:
                prior = line
                break
    if prior is None:
        prior = "        <a ${isActive(dial9Chevron ? '/retro/dial9.html' : '/retro/dial.html')}>Home</a>"
    text = text.replace(owned, prior, 1)
    retro_nav.write_text(text, encoding="utf-8")
    print("Cleaned: web/retro/js/navigation.js")

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
        r'\n    def get_home_dial_path\(self\):\n.*?'
        r'(?=\n    (?:#|def |@)|\Z)',
        "\n",
        text,
        count=1,
        flags=re.DOTALL,
    )
    web_server.write_text(text, encoding="utf-8")
    print("Cleaned: classes/web_server.py")
PY

sudo python3 -m py_compile "$APP_DIR/classes/web_server.py"
sudo find "$APP_DIR/classes" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
sudo chown -R pi:pi "$APP_DIR"
if [ "${STARGATE_ADDON_NO_RESTART:-0}" != "1" ]; then
  sudo systemctl start stargate.service
else
  echo "Stargate restart deferred by add-on manager."
fi

echo "=== SWITCH TO RETRO RESTORE COMPLETE ==="
