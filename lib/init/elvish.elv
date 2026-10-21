# asdf-extras init overlay for elvish
# This file keeps completion behavior delegated to `asdf completion elvish`
# and provides lightweight wrappers for update/install -u.

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

	if (eq $args[0] completion) {
		asdf-extras-dispatch completion $@args[1..]
		return
	}

	if (eq $args[0] update) {
		try {
			asdf-extras-dispatch update $@args[1..]
		} finally {
			echo 'asdf-extras: if asdf-extras was updated, start a new Elvish session to reload its initialization before using extras commands again.' >&2
		}
		return
	}

	if (eq $args[0] install) {
		for arg $args[1..] {
			if (or (eq $arg -u) (eq $arg --home) (eq $arg -p) (eq $arg --parent) (eq $arg --local)) {
				asdf-extras-dispatch install $@args[1..]
				return
			}
		}

		e:asdf install $@args[1..]
		return
	}

	e:asdf $@args
}
