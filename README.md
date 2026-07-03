# Switch To Retro

[![Downloads](https://img.shields.io/github/downloads/matelv-x/Switch-To-Retro/total?label=downloads)](https://github.com/matelv-x/Switch-To-Retro/releases)

Adds/removes the home-page redirect to Retro `dial.html` or `dial9.html`.

<img width="1318" height="213" alt="Retro_Switch" src="https://github.com/user-attachments/assets/0930d355-c3a0-4d6e-8f58-ada75638d099" />
<img width="1343" height="201" alt="Retro-2" src="https://github.com/user-attachments/assets/d9b1467c-e35b-4144-b76d-b1310e257a26" />


## Install

Method 1 — GitHub Clone (Recommended)

```bash
cd /home/pi
rm -rf Switch-To-Retro
git clone https://github.com/matelv-x/Switch-To-Retro.git
cd Switch-To-Retro
chmod +x switch-to-retro.sh restore-switch-to-retro.sh
sudo APP_DIR=/home/pi/sg1_v4 ./switch-to-retro.sh true retro/dial.html
sudo systemctl restart stargate.service
```

## Method 2 — ZIP Download

Download and extract the ZIP archive into:
```bash
/home/pi/Switch-To-Retro
```
Then run:
```bash
cd /home/pi/Switch-To-Retro
chmod +x install.sh restore.sh
sudo ./install.sh
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
- Routes selections from the original Address Book through the active Retro
  dialing page while the redirect is enabled.
- Includes restore script to remove the redirect patch.

## Original Address Book behavior

When `Switch-To-Retro` is enabled:

- selecting a destination in the original SG1 Address Book opens the active
  Retro dialing page;
- the selected address is preserved;
- Retro automatically begins dialing the selected glyphs.

When `Switch-To-Retro` is not enabled, the original SG1 Address Book continues
to open the original SG1 dialing interface. Installing the Retro folder alone
does not change this behavior.

Running `restore-switch-to-retro.sh` restores the original SG1 Address Book
behavior.

## Attribution and originality

The home redirect/config idea was inspired by Polklabs project:

https://github.com/jonnerd154/StargateProject-software/pull/120

matelv-x/Codex modification: this repository adapts that idea for SG1 v4 installs, adds the `retro/dial.html` / `retro/dial9.html` selector, and wires it into the local Stargate config/web-server flow.

How much is copied or changed: Small script-based config/web-server patch.
