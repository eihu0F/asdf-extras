# asdf-extras init overlay for elvish

fn asdf-extras-dispatch {|@args|
	if (or (not (has-env ASDF_EXTRAS_DISPATCHER)) (eq $E:ASDF_EXTRAS_DISPATCHER '')) {
		echo 'asdf-extras: dispatcher not set: ASDF_EXTRAS_DISPATCHER' >&2
		fail 'ASDF_EXTRAS_DISPATCHER is not set'
	}

	bash $E:ASDF_EXTRAS_DISPATCHER $@args
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
