# Fixed initialization for Fish. It must stay minimal and stable, because a
# running shell keeps it: every asdf call goes to `asdf-extras invoke`, which
# holds all the logic and follows the selected runtime. Put behavior in
# lib/extras/commands/invoke.bash, not here.
function asdf
	# The control file carries a marker that proves invoke ran, and the changes it
	# asks for in this shell. Without a usable runtime, run native asdf unchanged.
	set -l ctl (mktemp -t asdf-extras.XXXXXX)
	if test $status -ne 0
		command asdf $argv
		return $status
	end
	set -l rc 0
	switch "$ASDF_EXTRAS_INIT_ORIGIN"
		case plugin
			set -l plugin_name asdf-extras
			if set -q ASDF_EXTRAS_PLUGIN_NAME; and test -n "$ASDF_EXTRAS_PLUGIN_NAME"
				set plugin_name "$ASDF_EXTRAS_PLUGIN_NAME"
			end
			ASDF_EXTRAS_CONTROL="$ctl" command asdf cmd "$plugin_name" invoke -- --shell fish --protocol 1 -- $argv
			set rc $status
		case installed
			set -l exe (command asdf which asdf-extras 2>/dev/null)
			if test $status -eq 0
				ASDF_EXTRAS_CONTROL="$ctl" "$exe" invoke --shell fish --protocol 1 -- $argv
				set rc $status
			end
	end
	set -l handled 0
	while read -l line
		if test $handled -eq 0
			test "$line" = handled; or break
			set handled 1
			continue
		end
		test $rc -eq 0; or break
		set -l parts (string split -m 2 ' ' -- "$line")
		string match -rq '^ASDF_[A-Z0-9_]+$' -- "$parts[2]"; or continue
		switch "$parts[1]"
			case set
				test (count $parts) -eq 3; or continue
				set -gx $parts[2] "$parts[3]"
			case unset
				set -e -g $parts[2]
		end
	end <$ctl
	command rm -f $ctl
	if test $handled -eq 1
		return $rc
	end
	command asdf $argv
end
