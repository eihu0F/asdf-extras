fn candidates {|mode @args|
	try {
		if (eq $mode standalone) {
			bash $E:ASDF_EXTRAS_COMPLETION_HELPER --standalone $@args | from-lines
		} elif (eq $mode delegated) {
			bash $E:ASDF_EXTRAS_COMPLETION_HELPER --delegated $@args | from-lines
		} else {
			bash $E:ASDF_EXTRAS_COMPLETION_HELPER $@args | from-lines
		}
	} catch err {
		echo 'asdf-extras: Elvish completion query failed' >&2
		fail $err
	}
}
