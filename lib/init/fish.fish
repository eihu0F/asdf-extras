function __asdf_extras_dispatch
	if type -q asdf-extras
		asdf-extras $argv
		return $status
	end
	command asdf cmd asdf-extras $argv
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

	if test (count $argv) -ge 2; and test "$argv[1]" = "install"; and test "$argv[2]" = "-u"
		__asdf_extras_dispatch install $argv[3..-1]
		return $status
	end

	command asdf $argv
end
