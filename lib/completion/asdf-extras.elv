use ./common

fn complete {|@words|
	common:candidates standalone (all $words[1..])
}

fn register {
	set edit:completion:arg-completer[asdf-extras] = $complete~
}
