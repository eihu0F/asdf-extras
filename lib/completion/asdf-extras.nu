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

def asdf-extras-candidates [place: record] {
	let words = ($place.command | skip 1 | each {|word| asdf-extras-argument-value $word })
	let result = (^bash $env.ASDF_EXTRAS_COMPLETION_HELPER --standalone ...$words | complete)
	if $result.exit_code != 0 {
		let diagnostic = $"asdf-extras: completion failed: ($result.stderr | str trim)"
		print --stderr $diagnostic
		error make {msg: $diagnostic}
	}
	$result.stdout | lines
}

extern asdf-extras [...args: string@asdf-extras-candidates]
