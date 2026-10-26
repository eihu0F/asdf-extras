# Asks extras for candidates through the entry point recorded at load time.
fn query {|@args|
	var plugin = asdf-extras
	if (and (has-env ASDF_EXTRAS_PLUGIN_NAME) (not-eq $E:ASDF_EXTRAS_PLUGIN_NAME '')) {
		set plugin = $E:ASDF_EXTRAS_PLUGIN_NAME
	}
	if (eq $E:ASDF_EXTRAS_COMPLETION_ORIGIN plugin) {
		e:asdf cmd $plugin completion -- --candidates $@args
	} elif (eq $E:ASDF_EXTRAS_COMPLETION_ORIGIN installed) {
		e:asdf exec asdf-extras completion --candidates $@args
	} else {
		fail 'completion origin is not set: ASDF_EXTRAS_COMPLETION_ORIGIN'
	}
}

fn candidates {|mode @args|
	try {
		if (eq $mode standalone) {
			query --standalone $@args | from-lines
		} elif (eq $mode delegated) {
			query --delegated $@args | from-lines
		} else {
			query $@args | from-lines
		}
	} catch err {
		echo 'asdf-extras: Elvish completion query failed' >&2
		fail $err
	}
}
