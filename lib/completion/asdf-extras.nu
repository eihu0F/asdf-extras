def asdf-extras-candidates [place: record] {
	let words = ($place.command | skip 1)
	let result = (^bash $env.ASDF_EXTRAS_COMPLETION_HELPER --standalone ...$words | complete)
	if $result.exit_code != 0 {
		error make {msg: $"asdf-extras: completion failed: ($result.stderr | str trim)"}
	}
	$result.stdout | lines
}

extern asdf-extras [...args: string@asdf-extras-candidates]
