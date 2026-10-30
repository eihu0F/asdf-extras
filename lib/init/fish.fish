# Fixed initialization for Fish. It must stay minimal and stable, because a
# running shell keeps it: every asdf call goes to `asdf-extras invoke`, which
# holds all the logic and follows the selected runtime. Put behavior in
# lib/extras/commands/invoke.bash, not here.
function asdf
	# invoke gets a descriptor (3) that is read here: a marker proving it ran, and the
	# changes it asks for in this shell. Standard input, output and error are not
	# touched. Without a usable runtime, run native asdf unchanged.
	set -l ctl
	set -l rc 0
	switch "$ASDF_EXTRAS_INIT_ORIGIN"
		case plugin
			set -l plugin_name asdf-extras
			if set -q ASDF_EXTRAS_PLUGIN_NAME; and test -n "$ASDF_EXTRAS_PLUGIN_NAME"
				set plugin_name "$ASDF_EXTRAS_PLUGIN_NAME"
			end
			ASDF_EXTRAS_CONTROL_FD=3 command asdf cmd "$plugin_name" invoke -- --shell fish --protocol 1 -- $argv 3>| read -z ctl
			set rc $pipestatus[1]
		case installed
			set -l exe (command asdf which asdf-extras 2>/dev/null)
			if test $status -eq 0
				ASDF_EXTRAS_CONTROL_FD=3 "$exe" invoke --shell fish --protocol 1 -- $argv 3>| read -z ctl
				set rc $pipestatus[1]
			end
	end
	set -l lines (string split \n -- "$ctl")
	if test "$lines[1]" != handled
		command asdf $argv
		return $status
	end
	if test $rc -eq 0
		for line in $lines[2..-1]
			set -l parts (string split -m 2 ' ' -- "$line")
			string match -rq '^ASDF_[A-Z0-9_]+$' -- "$parts[2]"; or continue
			switch "$parts[1]"
				case set
					test (count $parts) -eq 3; or continue
					set -gx $parts[2] "$parts[3]"
				case unset
					set -e -g $parts[2]
			end
		end
	end
	return $rc
end
