def asdf-extras-argument-value [word: string] {
	let quote = ($word | str substring 0..0)
	if $quote not-in ['"' "'" '`'] {
		return $word
	}
	let closed = (($word | str length) > 1 and ($word | str ends-with $quote))
	let literal = (if $closed { $word } else { $word + $quote })
	if $quote == '"' {
		# NUON decodes string escapes without evaluating Nushell expressions.
		return ($literal | from nuon)
	}
	$literal | str substring 1..-2
}

# Asks extras for candidates through the entry point recorded at load time.
def asdf-extras-query [...args: string] {
	let origin = ($env.ASDF_EXTRAS_COMPLETION_ORIGIN? | default "")
	let plugin_name = ($env.ASDF_EXTRAS_PLUGIN_NAME? | default "asdf-extras")
	if $origin == "plugin" {
		^asdf cmd $plugin_name __complete -- ...$args | complete
	} else if $origin == "installed" {
		^asdf exec asdf-extras __complete ...$args | complete
	} else {
		{exit_code: 1, stdout: "", stderr: "completion origin is not set: ASDF_EXTRAS_COMPLETION_ORIGIN"}
	}
}

def asdf-extras-candidates [place: record] {
	let words = ($place.command | skip 1 | each {|word| asdf-extras-argument-value $word })
	let result = (asdf-extras-query "--standalone" ...$words)
	if $result.exit_code != 0 {
		let diagnostic = $"asdf-extras: completion failed: ($result.stderr | str trim)"
		print --stderr $diagnostic
		error make {msg: $diagnostic}
	}
	$result.stdout | lines
}

extern asdf-extras [...args: string@asdf-extras-candidates]
