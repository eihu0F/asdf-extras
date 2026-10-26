# Asks extras for candidates through the entry point recorded at load time.
function __asdf_extras_query
	switch "$ASDF_EXTRAS_COMPLETION_ORIGIN"
		case plugin
			set -l plugin_name asdf-extras
			if set -q ASDF_EXTRAS_PLUGIN_NAME; and test -n "$ASDF_EXTRAS_PLUGIN_NAME"
				set plugin_name "$ASDF_EXTRAS_PLUGIN_NAME"
			end
			command asdf cmd "$plugin_name" __complete -- $argv
		case installed
			command asdf exec asdf-extras __complete $argv
		case '*'
			return 1
	end
end

function __asdf_extras_standalone_candidates
	set -l words (commandline -opc)
	set -l current (commandline -ct)
	__asdf_extras_query --standalone $words[2..-1] "$current"
end

if not set -q __asdf_extras_standalone_registered
	complete -c asdf-extras -f -a '(__asdf_extras_standalone_candidates)'
	set -g __asdf_extras_standalone_registered 1
end
