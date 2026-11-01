# Fixed initialization for Bash and Zsh (lib/init/zsh.zsh loads it). It must stay
# minimal and stable, because a running shell keeps it: every asdf call goes to
# `asdf-extras invoke`, which holds all the logic and follows the selected
# runtime. Put behavior in lib/extras/commands/invoke.bash, not here.
asdf() {
	local ctl="" exe line rest name value rc=0 handled=0 shell_name=bash
	[[ -z "${ZSH_VERSION:-}" ]] || shell_name=zsh

	# invoke gets a descriptor (3) that is captured here: a marker proving it ran,
	# and the changes it asks for in this shell. Standard input, output and error
	# are not touched. Without a usable runtime, run native asdf unchanged.
	case "${ASDF_EXTRAS_INIT_ORIGIN:-}" in
	plugin)
		{
			ctl="$(ASDF_EXTRAS_CONTROL_FD=3 command asdf cmd "${ASDF_EXTRAS_PLUGIN_NAME:-asdf-extras}" invoke -- --shell "$shell_name" --protocol 1 -- "$@" 3>&1 1>&4 4>&-)" || rc=$?
		} 4>&1
		;;
	installed)
		if exe="$(command asdf which asdf-extras 2>/dev/null)"; then
			{
				ctl="$(ASDF_EXTRAS_CONTROL_FD=3 "$exe" invoke --shell "$shell_name" --protocol 1 -- "$@" 3>&1 1>&4 4>&-)" || rc=$?
			} 4>&1
		fi
		;;
	esac
	if [[ "${ctl%%$'\n'*}" != handled ]]; then
		command asdf "$@"
		return $?
	fi
	if ((rc == 0)); then
		rest="${ctl#handled}"
		while [[ -n "$rest" ]]; do
			rest="${rest#$'\n'}"
			line="${rest%%$'\n'*}"
			if [[ "$rest" == *$'\n'* ]]; then
				rest="${rest#*$'\n'}"
			else
				rest=""
			fi
			case "$line" in
			"set "*)
				name="${line#set }"
				value="${name#* }"
				name="${name%% *}"
				[[ "$name" =~ ^ASDF_[A-Z0-9_]+$ && "$line" == "set $name "* ]] || continue
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
	return "$rc"
}
