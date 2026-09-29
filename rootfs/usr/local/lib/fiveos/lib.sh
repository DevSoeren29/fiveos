# shellcheck shell=bash disable=SC2034
# Shared helpers for the FiveOS scripts (fiveos CLI and first boot setup).
# (SC2034: the settings below are used by the scripts that source this file.)

FIVEOS_VERSION="0.1.0"

FIVEM_USER="fivem"
FIVEM_HOME="/opt/fivem"
ART_DIR="$FIVEM_HOME/artifacts"
DATA_DIR="$FIVEM_HOME/server-data"
LOG_DIR="$FIVEM_HOME/logs"
RES_DIR="$DATA_DIR/resources/[fiveos]"
SERVER_CFG="$DATA_DIR/server.cfg"
SECRETS_CFG="$DATA_DIR/secrets.cfg"

FIVEOS_CONF="/etc/fiveos/fiveos.conf"
INSTALL_DIR="/etc/fiveos/install"
BACKUP_DIR="/var/backups/fiveos"
TMUX_SOCKET="fivem"

ARTIFACT_API="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"
CFX_DATA_REPO="https://github.com/citizenfx/cfx-server-data.git"
OXMYSQL_URL="https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip"

if [ -t 1 ]; then
	C_B=$'\e[1m' C_G=$'\e[32m' C_Y=$'\e[33m' C_R=$'\e[31m' C_0=$'\e[0m'
else
	C_B='' C_G='' C_Y='' C_R='' C_0=''
fi

info() { printf '%s==>%s %s\n' "$C_G$C_B" "$C_0" "$*"; }
warn() { printf '%sWARN:%s %s\n' "$C_Y$C_B" "$C_0" "$*" >&2; }
die() {
	printf '%sERROR:%s %s\n' "$C_R$C_B" "$C_0" "$*" >&2
	exit 1
}

require_root() {
	[ "$(id -u)" -eq 0 ] || die "This needs root privileges. Try: sudo fiveos $*"
}

valid_name() { [[ $1 =~ ^[A-Za-z0-9_]{1,32}$ ]]; }

# --- /etc/fiveos/fiveos.conf: KEY="value" lines, never contains secrets ---

conf_get() {
	[ -r "$FIVEOS_CONF" ] || return 0
	sed -n "s/^$1=\"\(.*\)\"\$/\1/p" "$FIVEOS_CONF" | tail -n 1
}

conf_set() {
	local tmp
	mkdir -p "$(dirname "$FIVEOS_CONF")"
	touch "$FIVEOS_CONF"
	tmp=$(mktemp)
	grep -v "^$1=" "$FIVEOS_CONF" > "$tmp" || true
	printf '%s="%s"\n' "$1" "$2" >> "$tmp"
	install -m 644 "$tmp" "$FIVEOS_CONF"
	rm -f "$tmp"
}

# --- escaping ---

# for SQL and PHP single-quoted strings
sql_esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }
# for values inside "..." in server.cfg
cfg_str() { printf '%s' "$1" | tr -d '"\\\n'; }
uri_enc() { jq -rn --arg v "$1" '$v|@uri'; }
random_pw() { tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32; }

# cfg_set FILE PREFIX LINE
# Replaces the first line starting with PREFIX (e.g. 'sv_hostname ') by LINE,
# or appends LINE. Keeps owner and permissions of FILE.
cfg_set() {
	local file=$1 tmp
	tmp=$(mktemp)
	PREFIX=$2 LINE=$3 awk '
		index($0, ENVIRON["PREFIX"]) == 1 { if (!done) print ENVIRON["LINE"]; done = 1; next }
		{ print }
		END { if (!done) print ENVIRON["LINE"] }' "$file" > "$tmp"
	cat "$tmp" > "$file"
	rm -f "$tmp"
}

# --- system info ---

primary_ip() {
	ip -4 route get 1.1.1.1 2>/dev/null |
		awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

fx_running() { systemctl is-active --quiet fivem; }

license_missing() {
	[ -r "$SECRETS_CFG" ] || return 1
	! grep -Eq '^sv_licenseKey "[^"]+"' "$SECRETS_CFG"
}

# --- FXServer artifacts ---

# artifact_url CHANNEL|URL -> download URL of fx.tar.xz
artifact_url() {
	case "$1" in
	http://* | https://*) printf '%s\n' "$1" ;;
	recommended | latest | optional | critical)
		curl -fsSL --retry 3 "$ARTIFACT_API" | jq -er --arg c "$1" '.[$c + "_download"]'
		;;
	*) die "Unknown channel '$1' (use recommended, latest, optional, critical or a fx.tar.xz URL)" ;;
	esac
}

# .../build_proot_linux/master/35245-6efb47d.../fx.tar.xz -> 35245
build_from_url() { basename "$(dirname "$1")" | cut -d- -f1; }

# install_artifacts [CHANNEL|URL]
# Installs FXServer to $ART_DIR, the previous build is kept in $ART_DIR.old.
install_artifacts() {
	local url build tmp
	url=$(artifact_url "${1:-recommended}") || die "Could not resolve the FXServer download URL."
	build=$(build_from_url "$url")
	info "Downloading FXServer build $build"
	# not in /tmp: it is a small tmpfs on Debian 13
	tmp=$(mktemp -d "$FIVEM_HOME/.download.XXXXXX")
	if ! curl -fL --retry 3 --progress-bar -o "$tmp/fx.tar.xz" "$url"; then
		rm -rf "$tmp"
		die "Download failed: $url"
	fi
	mkdir "$tmp/new"
	if ! tar -xJf "$tmp/fx.tar.xz" -C "$tmp/new"; then
		rm -rf "$tmp"
		die "Could not extract FXServer."
	fi
	echo "$build" > "$tmp/new/.fiveos-build"
	rm -rf "$ART_DIR.old"
	if [ -d "$ART_DIR" ]; then
		mv "$ART_DIR" "$ART_DIR.old"
	fi
	mv "$tmp/new" "$ART_DIR"
	rm -rf "$tmp"
	chown -R "$FIVEM_USER:$FIVEM_USER" "$ART_DIR"
	conf_set FXSERVER_BUILD "$build"
	info "FXServer build $build installed."
}
