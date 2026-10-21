def asdf-extras-asdf-candidates [place: record] {
	let command = ($place.command | first)
	let args = ($place.command | skip 1)
	let subcommand = ($command | split row " " | last)
	if $command == "asdf" {
		let native = ("asdf-extras-native-root " + ($args | str join " ") | commandline complete --detailed | each {|item| $item | reject span })
		return ($native | append {value: update, description: "Update asdf, plugins and tool versions"} | uniq-by value)
	}
	let mode = (if $subcommand == install { [--delegated] } else { [] })
	let values = ($args | each {|word| asdf-extras-argument-value $word })
	let query = (^bash $env.ASDF_EXTRAS_COMPLETION_HELPER ...$mode $subcommand ...$values | complete)
	if $query.exit_code != 0 {
		error make {msg: $"asdf-extras: completion failed: ($query.stderr | str trim)"}
	}
	let extras = ($query.stdout | lines)
	if $subcommand != install {
		return $extras
	}
	let normalized = ($args | where {|arg| (asdf-extras-argument-value $arg) not-in [-u --home -p --parent --local] })
	let native = ("asdf-extras-native-install " + ($normalized | str join " ") | commandline complete --detailed | each {|item| $item | reject span })
	$native | append ($extras | each {|value| {value: $value} }) | uniq-by value
}

def asdf-extras-completion-candidates [place: record] {
	let values = ($place.command | skip 1 | each {|word| asdf-extras-argument-value $word })
	let result = (^bash $env.ASDF_EXTRAS_COMPLETION_HELPER --standalone completion ...$values | complete)
	if $result.exit_code != 0 {
		error make {msg: $"asdf-extras: completion failed: ($result.stderr | str trim)"}
	}
	$result.stdout | lines
}

extern asdf [...args: string@asdf-extras-asdf-candidates]
extern "asdf install" [...args: string@asdf-extras-asdf-candidates]
extern "asdf update" [...args: string@asdf-extras-asdf-candidates]
extern "asdf completion" [...args: string@asdf-extras-completion-candidates]
