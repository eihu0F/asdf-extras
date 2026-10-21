def --env --wrapped asdf [...args: string@asdf-extras-asdf-candidates] {
	asdf-extras-run ...$args
}

def --env --wrapped "asdf install" [...args: string@asdf-extras-asdf-candidates] {
	asdf ...([install] ++ $args)
}

def --env --wrapped "asdf update" [...args: string@asdf-extras-asdf-candidates] {
	asdf ...([update] ++ $args)
}

def --env --wrapped "asdf completion" [...args: string@asdf-extras-completion-candidates] {
	asdf-extras-run ...([completion] ++ $args)
}
