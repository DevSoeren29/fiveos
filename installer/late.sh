#!/bin/sh
# FiveOS installer, runs as preseed/late_command. Hands the answers from
# early.sh to the installed system and installs the FiveOS files. The actual
# setup (MariaDB, phpMyAdmin, FXServer download) runs on the first boot,
# because services cannot be started inside the installer chroot.

# shellcheck disable=SC1091
. /usr/share/debconf/confmodule

T=/target
SRC=/cdrom/fiveos/rootfs
DEST=$T/etc/fiveos/install

mkdir -p "$DEST"
chmod 700 "$DEST"
for key in server_name license_key db_admin_user db_admin_password db_name db_user db_password; do
	RET=
	db_get "fiveos/$key" || RET=
	printf '%s' "$RET" > "$DEST/$key"
	chmod 600 "$DEST/$key"
	# do not leave passwords in the installer logs copied to /var/log/installer
	case "$key" in *password) db_set "fiveos/$key" "" ;; esac
done

cp -R "$SRC/." "$T/"

chmod 755 \
	"$T/usr/local/bin/fiveos" \
	"$T/usr/local/lib/fiveos/firstboot.sh" \
	"$T/usr/local/lib/fiveos/fx-stop.sh" \
	"$T/etc/update-motd.d/10-fiveos"
chmod 644 \
	"$T/usr/local/lib/fiveos/lib.sh" \
	"$T/etc/systemd/system/fiveos-firstboot.service" \
	"$T/etc/systemd/system/fivem.service" \
	"$T/etc/systemd/system-preset/80-fiveos.preset" \
	"$T/etc/logrotate.d/fiveos" \
	"$T/etc/issue"
# landing page (replaces Apache's default index.html)
find "$T/var/www/html" -type d -exec chmod 755 {} +
find "$T/var/www/html" -type f -exec chmod 644 {} +

# Debian's default legal notice is replaced by the FiveOS status (update-motd.d)
: > "$T/etc/motd"

in-target systemctl enable fiveos-firstboot.service

exit 0
