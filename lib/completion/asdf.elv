use ./common
use str

var native = $nil

fn complete {|@words|
	if (<= (count $words) 2) {
		$native $@words
		put update
		return
	}
	if (eq $words[1] update) {
		common:candidates extras (all $words[1..])
		return
	}
	if (eq $words[1] install) {
		var normalized = [$words[0] install]
		for word $words[2..-1] {
			if (not (has-value [-u --home -p --parent --local] $word)) {
				set normalized = [$@normalized $word]
			}
		}
		set normalized = [$@normalized $words[-1]]
		$native $@normalized
		common:candidates delegated (all $words[1..])
		return
	}
	$native $@words
}

fn register {
	if (has-key $edit:completion:arg-completer asdf) {
		var current = $edit:completion:arg-completer[asdf]
		if (is $current $complete~) {
			return
		}
		if (not (eq (kind-of $current) fn)) {
			echo 'asdf-extras: native Elvish completer is not a function; registration left unchanged' >&2
			fail 'invalid native Elvish completion registration'
		}
		set native = $current
	} else {
		var code = ''
		try {
			set code = (e:asdf completion elvish | slurp)
		} catch err {
			echo 'asdf-extras: could not generate native Elvish completion' >&2
			fail $err
		}
		if (eq (str:trim-space $code) '') {
			echo 'asdf-extras: native Elvish completion is empty' >&2
			fail 'empty native Elvish completion'
		}
		var generated = $nil
		try {
			eval $code &on-end={|scope| set generated = $scope}
		} catch err {
			echo 'asdf-extras: could not load native Elvish completion; configure a working native completer before init' >&2
			fail $err
		}
		if (has-key $edit:completion:arg-completer asdf) {
			set native = $edit:completion:arg-completer[asdf]
		} elif (has-key $generated arg-completer~) {
			set native = $generated[arg-completer~]
		} else {
			echo 'asdf-extras: native Elvish completion did not define or register an argument completer' >&2
			fail 'missing native Elvish completion handler'
		}
	}
	if (not (eq (kind-of $native) fn)) {
		echo 'asdf-extras: generated native Elvish completion handler is not a function' >&2
		fail 'invalid generated native Elvish completion handler'
	}
	set edit:completion:arg-completer[asdf] = $complete~
}
