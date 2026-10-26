# asdf-extras init overlay for nushell

def --env "asdf-extras-dispatch" [subcommand: string, ...args] {
	# Reach extras through the entry point this init came from, so a removed
	# runtime does not leave a stale path behind.
	let origin = ($env.ASDF_EXTRAS_INIT_ORIGIN? | default "")
	let plugin_name = ($env.ASDF_EXTRAS_PLUGIN_NAME? | default "asdf-extras")

	if $origin == "plugin" {
		^asdf cmd $plugin_name $subcommand -- ...$args
	} else if $origin == "installed" {
		^asdf exec asdf-extras $subcommand ...$args
	} else {
		error make {msg: "asdf-extras: entry point not set: ASDF_EXTRAS_INIT_ORIGIN"}
	}
}

def --env --wrapped asdf-extras-run [...args] {
	if (($args | get --optional 0 | default "") in [install update completion]) {
		if ("--help" in $args or "-h" in $args) {
			asdf-extras-dispatch help "--asdf" ...$args
			return
		}
	}

	if (($args | get --optional 0 | default "") in [help --help -h]) {
		asdf-extras-dispatch help "--asdf" ...$args
		return
	}

	if (($args | length) >= 1 and ($args | get 0) == "completion") {
		let completion_args = ($args | skip 1)
		if (($completion_args | get --optional 0 | default "") in [bash zsh fish nushell elvish]) {
			asdf-extras-dispatch completion "--asdf" "--wrappers" ...$completion_args
		} else {
			asdf-extras-dispatch completion ...$completion_args
		}
		return
	}

	if (($args | length) >= 1 and ($args | get 0) == "update") {
		try {
			asdf-extras-dispatch update ...($args | skip 1)
		} catch {|err|
			print --stderr 'asdf-extras: if asdf-extras was updated, start a new Nushell session to reload its initialization before using extras commands again.'
			error make $err
		}
		let update_status = $env.LAST_EXIT_CODE
		print --stderr 'asdf-extras: if asdf-extras was updated, start a new Nushell session to reload its initialization before using extras commands again.'
		$env.LAST_EXIT_CODE = $update_status
		return
	}

	if (($args | length) >= 1 and ($args | get 0) == "install") {
		let install_args = ($args | skip 1)
		let has_scope_flag = ($install_args | any {|x| $x == "-u" or $x == "--home" or $x == "-p" or $x == "--parent" or $x == "--local"})
		if $has_scope_flag {
			asdf-extras-dispatch install ...$install_args
			return
		}

		^asdf install ...$install_args
		return
	}

	^asdf ...$args
}

def --env --wrapped asdf [...args] {
	asdf-extras-run ...$args
}

# A native asdf module may define these subcommands, which take precedence over
# the root wrapper; route them through it explicitly.
def --env --wrapped "asdf install" [...args] {
	asdf ...([install] ++ $args)
}

def --env --wrapped "asdf update" [...args] {
	asdf ...([update] ++ $args)
}

def --env --wrapped "asdf completion" [...args] {
	asdf-extras-run ...([completion] ++ $args)
}

def --env --wrapped "asdf help" [...args] {
	asdf-extras-run ...([help] ++ $args)
}
