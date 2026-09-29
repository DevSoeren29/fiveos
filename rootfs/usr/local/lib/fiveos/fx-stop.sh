#!/bin/sh
# ExecStop of fivem.service: asks FXServer to quit cleanly, kills it after 30s.

tm() { tmux -L fivem "$@"; }

tm has-session -t fivem 2>/dev/null || exit 0
tm send-keys -t fivem 'quit "Server is shutting down"' Enter

i=0
while [ "$i" -lt 30 ]; do
	tm has-session -t fivem 2>/dev/null || exit 0
	sleep 1
	i=$((i + 1))
done
tm kill-session -t fivem
