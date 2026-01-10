.PHONY: test test-verbose lint

test:
	@zsh tests/test_plugin.zsh

test-verbose:
	@zsh tests/test_plugin.zsh --verbose

lint:
	@zsh -n zsh-jumper.plugin.zsh
