function __asdf_extras_standalone_candidates
	set -l words (commandline -opc)
	set -l current (commandline -ct)
	command bash "$ASDF_EXTRAS_COMPLETION_HELPER" --standalone $words[2..-1] "$current"
end

if not set -q __asdf_extras_standalone_registered
	complete -c asdf-extras -f -a '(__asdf_extras_standalone_candidates)'
	set -g __asdf_extras_standalone_registered 1
end
