# Switch To Retro

Adds/removes the home-page redirect to Retro `dial.html` or `dial9.html`.

This repository is private while it is being checked and verified.

## Install

Clone or unzip this add-on into `/home/pi`, then run:

```bash
cd /home/pi
rm -rf Switch-To-Retro
git clone https://github.com/matelv-x/Switch-To-Retro.git
cd Switch-To-Retro
chmod +x switch-to-retro.sh restore-switch-to-retro.sh
sudo APP_DIR=/home/pi/sg1_v4 ./switch-to-retro.sh true retro/dial.html
sudo systemctl restart stargate.service
```

## Restore / uninstall

```bash
cd /home/pi/Switch-To-Retro
sudo APP_DIR=/home/pi/sg1_v4 ./restore-switch-to-retro.sh
sudo systemctl restart stargate.service
```

## What it changes

- Adds config keys for Retro home redirect.
- Supports `retro/dial.html` and `retro/dial9.html`.
- Includes restore script to remove the redirect patch.

## Attribution and originality

The home redirect/config idea was inspired by Polklabs project:
https://github.com/polklabs/StargateProject-software/tree/Stargate-Retro-UI-Integration

matelv-x/Codex modification: this repository adapts that idea for SG1 v4 installs, adds the `retro/dial.html` / `retro/dial9.html` selector, and wires it into the local Stargate config/web-server flow.

How much is copied or changed: Small script-based config/web-server patch.
