fn asdf-extras-load-completion {|file|
	# Elvish 0.21 supports relative file imports, but not absolute file imports.
	use str
	var base = [(str:split / $pwd | each {|part| if (not-eq $part '') { put $part }})]
	var target = [(str:split / $file | each {|part| if (not-eq $part '') { put $part }})]
	while (and (> (count $base) 0) (> (count $target) 0) (eq $base[0] $target[0])) {
		set base = $base[1..]
		set target = $target[1..]
	}
	var relative = './'(str:join / [(each {|part| put ..} $base) $@target])
	eval 'use '(to-string (repr $relative))' completion; completion:register'
}
