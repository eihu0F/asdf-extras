# asdf-extras init overlay for elvish

use re
use str

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

# Sets or removes ASDF_<TOOL>_VERSION in this shell, so it must run here and not
# in a child process. Arguments are only ever data: they are validated before
# anything changes and never evaluated.
fn asdf-extras-shell {|@args|
	var usage = 'asdf-extras: usage: asdf shell <plugin> <version>... | asdf shell --unset <plugin>'
	var unset-override = $false

	if (and (> (count $args) 0) (eq $args[0] --unset)) {
		set unset-override = $true
		set args = $args[1..]
		if (!= (count $args) 1) {
			echo $usage >&2
			fail 'invalid asdf shell usage'
		}
	} elif (< (count $args) 2) {
		echo $usage >&2
		fail 'invalid asdf shell usage'
	}
	var plugin = $args[0]
	set args = $args[1..]
	if (not (re:match '^[A-Za-z0-9_][A-Za-z0-9_-]*$' $plugin)) {
		echo 'asdf-extras: invalid plugin name: '$plugin >&2
		fail 'invalid plugin name'
	}
	for version $args {
		if (not (re:match '^[A-Za-z0-9][A-Za-z0-9._+:/@~^-]*$' $version)) {
			echo 'asdf-extras: invalid version: '$version >&2
			fail 'invalid version'
		}
	}

	# The same normalization as native asdf: uppercase, with - as _.
	var variable = 'ASDF_'(str:to-upper (str:replace - _ $plugin))'_VERSION'
	if $unset-override {
		unset-env $variable
	} else {
		set-env $variable (str:join ' ' $args)
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

	if (and (has-value [install update get completion shell] $args[0]) (or (has-value $args --help) (has-value $args -h))) {
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

	if (eq $args[0] get) {
		asdf-extras-dispatch get (all $args[1..])
		return
	}

	if (eq $args[0] shell) {
		asdf-extras-shell (all $args[1..])
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
