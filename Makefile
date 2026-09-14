.PHONY: init deps

init:
	iex -S mix

deps:
	mix deps.get

clean:
	rm -rf _build/ deps/ mix.lock