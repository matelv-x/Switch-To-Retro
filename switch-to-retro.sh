#!/bin/bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/pi/sg1_v4}"
ENABLE_REDIRECT="${1:-true}"
REDIRECT_PAGE="${2:-retro/dial.html}"

if [ "$ENABLE_REDIRECT" != "true" ] && [ "$ENABLE_REDIRECT" != "false" ]; then
  echo "Usage: $0 [true|false] [retro/dial.html|retro/dial9.html]"
  exit 1
fi

if [ "$REDIRECT_PAGE" != "retro/dial.html" ] && [ "$REDIRECT_PAGE" != "retro/dial9.html" ]; then
  echo "Usage: $0 [true|false] [retro/dial.html|retro/dial9.html]"
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "App folder not found: $APP_DIR"
  exit 1
fi

if [ "$ENABLE_REDIRECT" = "true" ] && [ ! -f "$APP_DIR/web/$REDIRECT_PAGE" ]; then
  echo "Retro page not found: $APP_DIR/web/$REDIRECT_PAGE"
  echo "Copy web/retro into place first, or run: $0 false $REDIRECT_PAGE"
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  local file="$1"
  if [ -f "$file" ] && [ ! -f "${file}.bak-retro-${STAMP}" ]; then
    cp "$file" "${file}.bak-retro-${STAMP}"
  fi
}

backup_file "$APP_DIR/config/milkyway-config.json"
backup_file "$APP_DIR/config/defaults-milkyway/config.json.dist"
backup_file "$APP_DIR/web/index.htm"
backup_file "$APP_DIR/web/js/address_book.js"
backup_file "$APP_DIR/classes/web_server.py"

python3 - "$APP_DIR" "$ENABLE_REDIRECT" "$REDIRECT_PAGE" <<'PY'
import json
import sys
from pathlib import Path

app = Path(sys.argv[1])
enable = sys.argv[2] == "true"
redirect_page = sys.argv[3]

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

def update_config(path, active):
    data = json.loads(path.read_text(encoding="utf-8"))
    data["web_home_redirect_enabled"] = {
        "value": enable if active else False,
        "desc": "True to open the selected retro dialing page when visiting stargate.local",
        "type": "bool",
    }
    data["web_home_redirect_page"] = {
        "value": redirect_page,
        "desc": "Which retro dialing page should open when stargate.local is visited",
        "type": "str-enum",
        "enum_values": [
            "retro/dial.html",
            "retro/dial9.html",
        ],
    }
    write_json(path, data)

update_config(app / "config" / "milkyway-config.json", active=True)
update_config(app / "config" / "defaults-milkyway" / "config.json.dist", active=False)

home_redirect = app / "web" / "js" / "home_redirect.js"
home_redirect.write_text("""function applyHomeRedirect(continueCallback) {
  $.get('/stargate/get/config')
    .done(function(config) {
      const redirectConfig = config.web_home_redirect_enabled;
      const pageConfig = config.web_home_redirect_page;

      if (redirectConfig && redirectConfig.value) {
        const target = pageConfig && pageConfig.value ? pageConfig.value : 'retro/dial.html';
        const allowedTargets = ['retro/dial.html', 'retro/dial9.html'];
        window.location.replace('/' + (allowedTargets.includes(target) ? target : 'retro/dial.html'));
        return;
      }

      continueCallback();
    })
    .fail(function() {
      continueCallback();
    });
}
""", encoding="utf-8")

index_path = app / "web" / "index.htm"
index = index_path.read_text(encoding="utf-8")
script_line = '    <script src="/js/home_redirect.js"></script>'
if "/js/home_redirect.js" not in index:
    anchor = '    <script src="/lib/bootstrap-5/js/bootstrap.bundle.min.js"></script>'
    if anchor in index:
        index = index.replace(anchor, anchor + "\n" + script_line, 1)
    else:
        index = index.replace("</body>", script_line + "\n  </body>", 1)
    index_path.write_text(index, encoding="utf-8")

index = index_path.read_text(encoding="utf-8")
plain_startup = """      $(function() {
          loadDHDSymbols();
          doPoll();
      });"""
redirect_startup = """      $(function() {
          applyHomeRedirect(function() {
              loadDHDSymbols();
              doPoll();
          });
      });"""
if "applyHomeRedirect(function()" not in index:
    if plain_startup in index:
        index = index.replace(plain_startup, redirect_startup, 1)
    else:
        raise SystemExit("Could not find index.htm startup block to wrap with applyHomeRedirect")
    index_path.write_text(index, encoding="utf-8")

address_book_path = app / "web" / "js" / "address_book.js"
address_book = address_book_path.read_text(encoding="utf-8")
original_dial_target = "window.location = \\'index.htm?address="
retro_dial_target = "window.location = \\'/dial?address="
if enable:
    address_book = address_book.replace(original_dial_target, retro_dial_target)
else:
    address_book = address_book.replace(retro_dial_target, original_dial_target)
address_book_path.write_text(address_book, encoding="utf-8")

retro_nav_path = app / "web" / "retro" / "js" / "navigation.js"
if retro_nav_path.exists():
    retro_nav = retro_nav_path.read_text(encoding="utf-8")
    old_home = "        <a ${isActive(dial9Chevron ? '/retro/dial9.html' : '/retro/dial.html')}>Home</a>"
    new_home = '        <a href="/">Home</a>'
    if old_home in retro_nav:
        retro_nav = retro_nav.replace(old_home, new_home, 1)
        retro_nav_path.write_text(retro_nav, encoding="utf-8")

web_server_path = app / "classes" / "web_server.py"
web_server = web_server_path.read_text(encoding="utf-8")

if 'request_path == "/dial"' not in web_server:
    marker = "            request_path, get_vars = self.parse_get_vars()\n"
    injection = """
            if request_path == "/dial":
                target = self.get_home_dial_path()
                query = urllib.parse.urlparse(self.path).query
                self.send_response(302)
                self.send_header("Location", target + ("?" + query if query else ""))
                self.end_headers()
                return
"""
    if marker not in web_server:
        raise SystemExit("Could not find do_GET parse marker in classes/web_server.py")
    web_server = web_server.replace(marker, marker + injection, 1)

if "def get_home_dial_path(self):" not in web_server:
    helper = """

    def get_home_dial_path(self):
        try:
            page = self.stargate.cfg.get("web_home_redirect_page")
        except Exception:
            page = "retro/dial.html"

        if page not in ("retro/dial.html", "retro/dial9.html"):
            page = "retro/dial.html"

        return "/" + page
"""
    web_server = web_server.rstrip() + helper + "\n"

web_server_path.write_text(web_server, encoding="utf-8")
PY

python3 -m json.tool "$APP_DIR/config/milkyway-config.json" >/dev/null
python3 -m json.tool "$APP_DIR/config/defaults-milkyway/config.json.dist" >/dev/null
PYTHONDONTWRITEBYTECODE=1 python3 - <<PY
import py_compile
py_compile.compile("$APP_DIR/classes/web_server.py", cfile="/tmp/stargate_web_server_retro_check.pyc", doraise=True)
PY
rm -f /tmp/stargate_web_server_retro_check.pyc

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart stargate.service || true
fi

echo "Retro home redirect patch applied."
echo "Enabled: $ENABLE_REDIRECT"
echo "Page: $REDIRECT_PAGE"
echo "Backups: *.bak-retro-${STAMP}"
