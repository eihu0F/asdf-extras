function __asdf_extras_completion_candidates
	set -l words (commandline -opc)
	set -l current (commandline -ct)
	__asdf_extras_query $words[2..-1] "$current"
end

function __asdf_extras_needs_completion
	set -l words (commandline -opc)
	test (count $words) -le 1; or contains -- $words[2] install update get
end

if not set -q __asdf_extras_completion_registered
	if test (count (complete -c asdf)) -eq 0
		set -l native (command asdf completion fish)
		if test $status -ne 0
			echo 'asdf-extras: could not load native Fish completion' >&2
			return 1
		end
		printf '%s\n' $native | source; or begin
			echo 'asdf-extras: could not evaluate native Fish completion' >&2
			return 1
		end
		if test (count (complete -c asdf)) -eq 0
			echo 'asdf-extras: native Fish completion did not register asdf' >&2
			return 1
		end
	end
	complete -c asdf -f -n __asdf_extras_needs_completion -a '(__asdf_extras_completion_candidates)'
	set -g __asdf_extras_completion_registered 1
end
