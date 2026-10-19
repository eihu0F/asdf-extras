# asdf-extras init overlay for elvish
# This file keeps completion behavior delegated to `asdf completion elvish`
# and provides lightweight wrappers for update/install -u.

fn asdf-extras-dispatch [@args]{
	if (has-external asdf-extras) {
		asdf-extras $@args
	} else {
		asdf cmd extras $@args
	}
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

	if (and (>= (count $args) 2) (== $args[0] install) (== $args[1] -u)) {
		asdf-extras-dispatch install $@args[2..]
		return
	}

	asdf $@args
}
