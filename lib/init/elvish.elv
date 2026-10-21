# asdf-extras init overlay for elvish
# This file keeps completion behavior delegated to `asdf completion elvish`
# and provides lightweight wrappers for update/install -u.

fn asdf-extras-dispatch [@args]{
	if (or (not (has-env ASDF_EXTRAS_DISPATCHER)) (== $E:ASDF_EXTRAS_DISPATCHER '')) {
		echo 'asdf-extras: dispatcher not set: ASDF_EXTRAS_DISPATCHER' >&2
		return 1
	}

	bash $E:ASDF_EXTRAS_DISPATCHER $@args
}

fn asdf [@args]{
	if (== (count $args) 0) {
		asdf
		return
	}

	if (== $args[0] completion) {
		asdf-extras-dispatch completion $@args[1..]
		return
	}

	if (== $args[0] update) {
		asdf-extras-dispatch update $@args[1..]
		return
	}

	if (== $args[0] install) {
		for arg $args[1..] {
			if (or (== $arg -u) (== $arg --home) (== $arg -p) (== $arg --parent) (== $arg --local)) {
				asdf-extras-dispatch install $@args[1..]
				return
			}
		}

		asdf install $@args[1..]
		return
	}

	asdf $@args
}
