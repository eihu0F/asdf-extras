# Fish adds rules to the native ones, which stay in place. The condition asks the
# runtime once per completion and remembers its answer for the candidates, so the
# runtime decides which words are completed by asdf-extras (they get no file
# completion) and which are left to native completion.
function __asdf_extras_claims
	set -l words (commandline -opc)
	set -l current (commandline -ct)
	set -g __asdf_extras_answer (__asdf_extras_query --cword (count $words) -- $words "$current")
	set -g __asdf_extras_answer_status $status
	# 2: no runtime. Otherwise a failure is reported through the candidates.
	test $__asdf_extras_answer_status -ne 2; or return 1
	test $__asdf_extras_answer_status -ne 0; and return 0
	test "$__asdf_extras_answer[1]" != 'native original'; or test (count $__asdf_extras_answer) -gt 1
end

function __asdf_extras_completion_candidates
	set -l answer $__asdf_extras_answer
	set -l answer_status $__asdf_extras_answer_status
	set -e __asdf_extras_answer
	set -e __asdf_extras_answer_status
	test "$answer_status" = 0; or return 1
	if test (count $answer) -gt 1
		printf '%s\n' $answer[2..-1]
	end
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
	complete -c asdf -f -n __asdf_extras_claims -a '(__asdf_extras_completion_candidates)'
	set -g __asdf_extras_completion_registered 1
end
