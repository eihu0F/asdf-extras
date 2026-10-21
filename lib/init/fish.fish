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

function asdf
	if test (count $argv) -ge 1; and test "$argv[1]" = "completion"
		__asdf_extras_dispatch completion $argv[2..-1]
		return $status
	end

	if test (count $argv) -ge 1; and test "$argv[1]" = "update"
		__asdf_extras_dispatch update $argv[2..-1]
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
