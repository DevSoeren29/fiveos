# FiveOS

A minimal, command line only Linux distribution for running **FiveM servers**.
Boot the ISO, answer a few questions (names and passwords), and you get a
ready-to-use server with FXServer, MariaDB and phpMyAdmin — preconfigured and
managed with a single `fiveos` command.

FiveOS is based on **Debian 13 "trixie"** (amd64). It installs no desktop and
no "standard system utilities" — only what a FiveM server needs.

## What you get

| Component    | Details |
|--------------|---------|
| FXServer     | Current *recommended* build, downloaded on first boot, runs as `fivem.service` |
| Resources    | [cfx-server-data](https://github.com/citizenfx/cfx-server-data) defaults + [oxmysql](https://github.com/overextended/oxmysql) |
| MariaDB      | FiveM database + user, admin user, `mysql_connection_string` written for you |
| phpMyAdmin   | `http://<server-ip>/phpmyadmin`, log in with the database admin user |
| Firewall     | ufw: only 22 (SSH), 80 (phpMyAdmin), 30120 TCP/UDP (FiveM) open |
| `fiveos` CLI | start/stop, live console, logs, updates, resources, backups, firewall |

## Installation

During installation you are asked for:

1. Language, keyboard layout and location (standard Debian installer)
2. **FiveOS:** server name, FiveM license key (optional), database admin user +
   password, FiveM database name, database user + password
3. Your Linux user name and password (gets `sudo`)
4. The disk to install to — **the whole disk is erased** after you confirm

Everything else runs unattended. After the reboot FiveOS finishes the setup
(needs internet, takes a few minutes) and shows the connect address.

Get a license key at <https://portal.cfx.re>. Without it the server does not
start; you can add it later with `sudo fiveos config license <key>`.

## Testing in VirtualBox

1. **New VM:** Type *Linux*, Version *Debian (64-bit)*, **2+ CPUs, 4 GB RAM,
   30 GB disk**. Select the FiveOS ISO. Disable *Unattended installation*.
2. **Network:** set the adapter to **Bridged Adapter** so the VM gets its own IP
   in your network and you can connect from FiveM on your PC.
   (With NAT you need port forwarding for 30120 TCP+UDP, 80 and 22.)
3. Start the VM, choose *Install* or *Graphical install*, answer the questions.
4. After the reboot, watch the first boot setup on the console. The login
   screen shows the IP address.
5. In FiveM press F8 and type `connect <ip>:30120`.

## The `fiveos` command

```
fiveos status                     # state, IP, build, connect address
sudo fiveos start|stop|restart
sudo fiveos console               # live console, leave with Ctrl+B, D
fiveos logs -f
sudo fiveos update [latest]       # new FXServer build (default: recommended)
sudo fiveos rollback              # back to the previous build
sudo fiveos config license <key>
sudo fiveos config hostname "My Server"
sudo fiveos config maxclients 64
fiveos resource list
sudo fiveos resource add https://github.com/user/my-resource.git
sudo fiveos resource remove my-resource
fiveos db info
sudo fiveos db backup
sudo fiveos backup                # server files + database
sudo fiveos firewall allow 40120/tcp
sudo fiveos setup                 # retry the setup if the first boot failed
```

## File layout on the server

| Path | Content |
|------|---------|
| `/opt/fivem/artifacts` | FXServer (previous build in `artifacts.old`) |
| `/opt/fivem/server-data` | `server.cfg`, `secrets.cfg`, `resources/` |
| `/opt/fivem/server-data/resources/[fiveos]` | resources added with `fiveos resource add` |
| `/opt/fivem/logs/fxserver.log` | server log (rotated weekly) |
| `/etc/fiveos/fiveos.conf` | FiveOS state (no secrets) |
| `/var/backups/fiveos` | backups |
| `/var/log/fiveos-setup.log` | first boot log |

FXServer runs as the system account `fxserver`. Your Linux user is in the
`fxserver` group and can edit the server files directly
(e.g. via SFTP).

## Building the ISO

The build remasters the official Debian netinst ISO (Linux or WSL2):

```bash
sudo apt install xorriso cpio wget
bash build/build-iso.sh
```

The ISO is written to `out/fiveos-<version>-amd64.iso`. GitHub Actions builds
it on every push as well (see `.github/workflows/build-iso.yml`).

On Windows, install WSL2 first (`wsl --install -d Debian`) and run the build
inside it.

## Releases and website

- Push a tag like `v0.1.0` to build the ISO and publish it as a GitHub release.
- `website/` is the project website (features, installation guide, commands,
  FAQ, download). It is deployed to GitHub Pages by
  `.github/workflows/pages.yml` — enable *Settings → Pages → Source: GitHub
  Actions* once. The download buttons use the latest GitHub release; set the
  repository in `website/assets/config.js` if the site is not hosted on
  `<owner>.github.io/<repo>`.

## How it works

```
installer/preseed.cfg      answers for the Debian installer (packages, partitioning, ...)
installer/early.sh         asks the FiveOS questions at the start of the installation
installer/late.sh          copies answers + rootfs into the new system
rootfs/                    files installed into the system (CLI, services, configs)
  usr/local/lib/fiveos/firstboot.sh   configures MariaDB, phpMyAdmin, FXServer, firewall
build/build-iso.sh         builds the ISO
website/                   project website (GitHub Pages)
```

Services cannot be started inside the installer, so the database and FXServer
setup happens on the first boot (`fiveos-firstboot.service`). Passwords are
stored root-only in `/etc/fiveos/install` until then and deleted afterwards.

## Legal

FiveOS is not affiliated with Cfx.re, Rockstar Games or Take-Two Interactive.
FXServer is **not** distributed with FiveOS; it is downloaded from the official
Cfx.re servers during setup. By running a FiveM server you agree to the
[Cfx.re terms](https://fivem.net/terms).

FiveOS itself is licensed under the MIT license, see [LICENSE](LICENSE).
