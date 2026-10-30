# Fixed initialization for Bash and Zsh (lib/init/zsh.zsh loads it). It must stay
# minimal and stable, because a running shell keeps it: every asdf call goes to
# `asdf-extras invoke`, which holds all the logic and follows the selected
# runtime. Put behavior in lib/extras/commands/invoke.bash, not here.
asdf() {
	local ctl exe line rest name value rc=0 handled=0 shell_name=bash
	[[ -z "${ZSH_VERSION:-}" ]] || shell_name=zsh

	# The control file carries a marker that proves invoke ran, and the changes it
	# asks for in this shell. Without a usable runtime, run native asdf unchanged.
	if ctl="$(mktemp -t asdf-extras.XXXXXX)"; then
		case "${ASDF_EXTRAS_INIT_ORIGIN:-}" in
		plugin) ASDF_EXTRAS_CONTROL="$ctl" command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" invoke -- --shell "$shell_name" --protocol 1 -- "$@" || rc=$? ;;
		installed)
			if exe="$(command asdf which asdf-extras 2>/dev/null)"; then
				ASDF_EXTRAS_CONTROL="$ctl" "$exe" invoke --shell "$shell_name" --protocol 1 -- "$@" || rc=$?
			fi
			;;
		esac
		{
			if IFS= read -r line && [[ "$line" == handled ]]; then
				handled=1
				while ((rc == 0)) && IFS= read -r line; do
					case "$line" in
					"set "*)
						rest="${line#set }"
						name="${rest%% *}"
						value="${rest#* }"
						[[ "$name" =~ ^ASDF_[A-Z0-9_]+$ && "$rest" == *" "* ]] || continue
						export "$name=$value"
						;;
					"unset "*)
						name="${line#unset }"
						[[ "$name" =~ ^ASDF_[A-Z0-9_]+$ ]] || continue
						unset -v "$name"
						;;
					esac
				done
			fi
		} <"$ctl"
		command rm -f "$ctl"
	fi
	if ((handled)); then
		return "$rc"
	fi
	command asdf "$@"
}
