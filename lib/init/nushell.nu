# asdf-extras init overlay for nushell

def "asdf-extras-dispatch" [...args] {
	let dispatcher = ($env.ASDF_EXTRAS_DISPATCHER? | default "")

	if $dispatcher == "" {
		error make {msg: "asdf-extras: dispatcher not set: ASDF_EXTRAS_DISPATCHER"}
	}

	^bash $dispatcher ...$args
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

	if (($args | length) >= 1 and ($args | get 0) == "install") {
		let install_args = ($args | skip 1)
		let has_scope_flag = ($install_args | any {|x| $x == "-u" or $x == "--home" or $x == "-p" or $x == "--parent"})
		if $has_scope_flag {
			asdf-extras-dispatch install ...$install_args
			return
		}

		^asdf install ...$install_args
		return
	}

	^asdf ...$args
}
