set -g __asdf_extras_init_file (status filename)

function __asdf_extras_dispatch
	set -l init_dir (dirname "$__asdf_extras_init_file")
	set -l lib_dir (dirname "$init_dir")
	set -l dispatcher "$lib_dir/commands/dispatch.bash"

	if not test -r "$dispatcher"
		echo "asdf-extras: dispatcher not found: $dispatcher" >&2
		return 1
	end

	command bash "$dispatcher" $argv
end

function __asdf_extras_refresh
	set -l previous "$argv[1]"
	set -l update_rc "$argv[2]"
	set -l executable (command asdf which asdf-extras)
	if test $status -ne 0
		echo 'asdf-extras: cannot resolve updated executable; retry asdf-extras init fish | source after fixing version selection' >&2
		return 1
	end
	if test "$executable" = "$previous"
		return $update_rc
	end
	# init does not load completion, so reload it only where it was enabled,
	# in the same mode (the asdf overlay sets __asdf_extras_completion_registered).
	set -l completion_args
	if set -q ASDF_EXTRAS_COMPLETION_HELPER; and test -n "$ASDF_EXTRAS_COMPLETION_HELPER"
		set completion_args completion
		if set -q __asdf_extras_completion_registered
			set -a completion_args --asdf
		end
		set -a completion_args fish
	end
	set -l init_code ("$executable" init fish)
	if test $status -ne 0; or test (count $init_code) -eq 0
		echo 'asdf-extras: cannot generate initialization; retry asdf-extras init fish | source' >&2
		return 1
	end
	set -l joined_code (string join \n -- $init_code | string collect)
	if not eval "$joined_code"
		echo 'asdf-extras: initialization failed; retry asdf-extras init fish | source' >&2
		return 1
	end
	if test (count $completion_args) -gt 0
		set -l completion_code ("$executable" $completion_args)
		if test $status -ne 0; or test (count $completion_code) -eq 0
			echo "asdf-extras: cannot generate completion; retry asdf-extras $completion_args | source" >&2
			return 1
		end
		set -l joined_completion (string join \n -- $completion_code | string collect)
		if not eval "$joined_completion"
			echo "asdf-extras: completion reload failed; retry asdf-extras $completion_args | source" >&2
			return 1
		end
	end
	return $update_rc
end

function asdf
	if test (count $argv) -ge 1; and contains -- "$argv[1]" install update completion
		if contains -- --help $argv; or contains -- -h $argv
			__asdf_extras_dispatch help --asdf $argv
			return $status
		end
	end

	if test (count $argv) -ge 1; and contains -- "$argv[1]" help --help -h
		__asdf_extras_dispatch help --asdf $argv
		return $status
	end

	if test (count $argv) -ge 1; and test "$argv[1]" = "completion"
		if test (count $argv) -ge 2; and contains -- "$argv[2]" bash zsh fish nushell elvish
			__asdf_extras_dispatch completion --asdf --wrappers $argv[2..-1]
		else
			__asdf_extras_dispatch completion $argv[2..-1]
		end
		return $status
	end

	if test (count $argv) -ge 1; and test "$argv[1]" = "update"
		set -l previous (command asdf which asdf-extras)
		if test $status -ne 0
			echo 'asdf-extras: cannot resolve current executable before update' >&2
			return 1
		end
		__asdf_extras_dispatch update $argv[2..-1]
		set -l update_rc $status
		__asdf_extras_refresh "$previous" "$update_rc"
		return $status
	end

	if test (count $argv) -ge 1; and test "$argv[1]" = "install"
		for arg in $argv[2..-1]
			if test "$arg" = "-u"; or test "$arg" = "--home"; or test "$arg" = "-p"; or test "$arg" = "--parent"; or test "$arg" = "--local"
				__asdf_extras_dispatch install $argv[2..-1]
				return $status
			end
		end
		command asdf install $argv[2..-1]
		return $status
	end

	command asdf $argv
end
