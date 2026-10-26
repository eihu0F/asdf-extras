# asdf-extras init overlay for elvish

fn asdf-extras-dispatch {|subcommand @args|
	# Reach extras through the entry point this init came from, so a removed
	# runtime does not leave a stale path behind.
	if (eq $E:ASDF_EXTRAS_INIT_ORIGIN plugin) {
		var plugin = asdf-extras
		if (and (has-env ASDF_EXTRAS_PLUGIN_NAME) (not-eq $E:ASDF_EXTRAS_PLUGIN_NAME '')) {
			set plugin = $E:ASDF_EXTRAS_PLUGIN_NAME
		}
		e:asdf cmd $plugin $subcommand -- $@args
	} elif (eq $E:ASDF_EXTRAS_INIT_ORIGIN installed) {
		e:asdf exec asdf-extras $subcommand $@args
	} else {
		echo 'asdf-extras: entry point not set: ASDF_EXTRAS_INIT_ORIGIN' >&2
		fail 'ASDF_EXTRAS_INIT_ORIGIN is not set'
	}
}

fn asdf {|@args|
	if (== (count $args) 0) {
		e:asdf
		return
	}

	if (has-value [help --help -h] $args[0]) {
		asdf-extras-dispatch help --asdf $@args
		return
	}

	if (and (has-value [install update completion] $args[0]) (or (has-value $args --help) (has-value $args -h))) {
		asdf-extras-dispatch help --asdf $@args
		return
	}

	if (eq $args[0] completion) {
		if (and (> (count $args) 1) (has-value [bash zsh fish nushell elvish] $args[1])) {
			asdf-extras-dispatch completion --asdf --wrappers (all $args[1..])
		} else {
			asdf-extras-dispatch completion (all $args[1..])
		}
		return
	}

	if (eq $args[0] update) {
		try {
			asdf-extras-dispatch update (all $args[1..])
		} finally {
			echo 'asdf-extras: if asdf-extras was updated, start a new Elvish session to reload its initialization before using extras commands again.' >&2
		}
		return
	}

	if (eq $args[0] install) {
		for arg $args[1..] {
			if (or (eq $arg -u) (eq $arg --home) (eq $arg -p) (eq $arg --parent) (eq $arg --local)) {
				asdf-extras-dispatch install (all $args[1..])
				return
			}
		}

		e:asdf install (all $args[1..])
		return
	}

	e:asdf $@args
}
