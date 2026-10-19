# asdf-extras init overlay for nushell

def "asdf-extras-dispatch" [...args] {
	if (which asdf-extras | is-not-empty) {
		^asdf-extras ...$args
	} else {
		^asdf cmd extras ...$args
	}
}

def --wrapped asdf [...args] {
	if (($args | length) >= 1 and ($args | get 0) == "completion") {
		asdf-extras-dispatch completion ...($args | skip 1)
		return
	}

	if (($args | length) >= 1 and ($args | get 0) == "update") {
		asdf-extras-dispatch update ...($args | skip 1)
		return
	}

	if (($args | length) >= 2 and ($args | get 0) == "install" and ($args | get 1) == "-u") {
		asdf-extras-dispatch install ...($args | skip 2)
		return
	}

	^asdf ...$args
}
