# Asks the runtime for completion (asdf-extras invoke --complete) through the
# entry point recorded at load time. Returns 2 when no runtime can be resolved.
function __asdf_extras_query
	switch "$ASDF_EXTRAS_COMPLETION_ORIGIN"
		case plugin
			set -l plugin_name asdf-extras
			if set -q ASDF_EXTRAS_PLUGIN_NAME; and test -n "$ASDF_EXTRAS_PLUGIN_NAME"
				set plugin_name "$ASDF_EXTRAS_PLUGIN_NAME"
			end
			command asdf cmd "$plugin_name" invoke -- --complete --shell fish --protocol 1 $argv
		case installed
			set -l exe (command asdf which asdf-extras 2>/dev/null)
			or return 2
			"$exe" invoke --complete --shell fish --protocol 1 $argv
		case '*'
			return 2
	end
end

# Prints the candidates the runtime returns for the command line so far. The
# first line of its answer only matters to callers that run native completion.
function __asdf_extras_candidates
	set -l words (commandline -opc)
	set -l current (commandline -ct)
	set -l answer (__asdf_extras_query $argv --cword (count $words) -- $words "$current")
	set -l query_status $status
	test $query_status -eq 0; or return $query_status
	if test (count $answer) -gt 1
		printf '%s\n' $answer[2..-1]
	end
end

function __asdf_extras_standalone_candidates
	__asdf_extras_candidates --standalone
end

if not set -q __asdf_extras_standalone_registered
	complete -c asdf-extras -f -a '(__asdf_extras_standalone_candidates)'
	set -g __asdf_extras_standalone_registered 1
end
