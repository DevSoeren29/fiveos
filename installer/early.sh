#!/bin/sh
# FiveOS installer, runs as preseed/early_command (busybox sh inside the
# Debian installer). Asks the FiveOS questions up front, so the rest of the
# installation can run unattended. The answers stay in the installer's
# debconf database until late.sh hands them to the installed system.

debconf-loadtemplate fiveos /fiveos/fiveos.templates

# shellcheck disable=SC1091
. /usr/share/debconf/confmodule

NAME_RE='^[A-Za-z0-9_]{1,32}$'

show_error() {
	db_subst fiveos/error MESSAGE "$1"
	db_fset fiveos/error seen false
	db_input critical fiveos/error || true
	db_go || true
}

# ask QUESTION -> answer in $RET
ask() {
	db_fset "$1" seen false
	db_input critical "$1" || true
	db_go || true
	db_get "$1"
}

# ask_name QUESTION RESERVED... -> validated identifier in $RET
ask_name() {
	q=$1
	shift
	while :; do
		ask "$q"
		if ! echo "$RET" | grep -Eq "$NAME_RE"; then
			show_error "Please use only letters, digits and underscores (1 to 32 characters)."
			continue
		fi
		reserved=
		for r in "$@"; do
			[ "$RET" = "$r" ] && reserved=1
		done
		if [ -n "$reserved" ]; then
			show_error "'$RET' is reserved or already used. Please choose another name."
			continue
		fi
		return
	done
}

# ask_password QUESTION CONFIRM_QUESTION
ask_password() {
	while :; do
		ask "$1"
		pw=$RET
		ask "$2"
		if [ "$pw" != "$RET" ]; then
			show_error "The passwords do not match."
		elif [ ${#pw} -lt 8 ]; then
			show_error "The password must be at least 8 characters long."
		else
			db_set "$2" ""
			return
		fi
		db_set "$1" ""
		db_set "$2" ""
	done
}

db_input critical fiveos/intro || true
db_go || true

while :; do
	ask fiveos/server_name
	name=$(echo "$RET" | tr -d '"\\')
	if [ -n "$name" ]; then
		db_set fiveos/server_name "$name"
		break
	fi
	show_error "The server name must not be empty."
done

while :; do
	ask fiveos/license_key
	echo "$RET" | grep -Eq '^[A-Za-z0-9_]*$' && break
	show_error "The license key may only contain letters, digits and underscores."
done

ask_name fiveos/db_admin_user root mysql phpmyadmin mariadb.sys
admin_user=$RET
ask_password fiveos/db_admin_password fiveos/db_admin_password_again

ask_name fiveos/db_name mysql information_schema performance_schema sys phpmyadmin

ask_name fiveos/db_user root mysql phpmyadmin mariadb.sys "$admin_user"
ask_password fiveos/db_password fiveos/db_password_again

exit 0
