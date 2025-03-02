.DEFAULT_GOAL := all

.PHONY: all
all:
	opam exec -- dune build --root .

.PHONY: deps
deps: create_switch ## Install development dependencies
	opam install -y ocamlformat=0.25.1 ocaml-lsp-server
	opam install -y --deps-only --with-test --with-doc .

.PHONY: create_switch
create_switch: ## Create switch and pinned opam repo
	opam switch create . 4.14.1 --no-install --repos pin=git+https://github.com/ocaml/opam-repository#9cf27a6683dc4e56ccf7e35c008198828bd5c267

.PHONY: switch
switch: deps ## Create an opam switch and install development dependencies

.PHONY: lock
lock: ## Generate a lock file
	opam lock -y .

.PHONY: build
build: ## Build the project, including non installable libraries and executables
	opam exec -- dune build --root .

.PHONY: playground
playground:
	make build -C playground

.PHONY: install
install: all ## Install the packages on the system
	opam exec -- dune install --root .

.PHONY: start
start: all ## Run the produced executable
	opam exec -- dune exec src/ocamlorg_web/bin/main.exe

.PHONY: test
test: ## Run the unit tests
	opam exec -- dune build --root . @runtest

.PHONY: clean
clean: ## Clean build artifacts and other generated files
	opam exec -- dune clean --root .

.PHONY: doc
doc: ## Generate odoc documentation
	opam exec -- dune build --root . @doc

.PHONY: fmt
fmt: ## Format the codebase with ocamlformat
	opam exec -- dune build --root . --auto-promote @fmt
	make -C playground fmt

.PHONY: watch
watch: ## Watch for the filesystem and rebuild on every change
	opam exec -- dune build @run -w --force --no-buffer

.PHONY: utop
utop: ## Run a REPL and link with the project's libraries
	opam exec -- dune utop --root . . -- -implicit-bindings

.PHONY: scrape
scrape: ## Generate the po files
	opam exec -- dune exec --root . tool/ood-gen/bin/scrape.exe planet
	opam exec -- dune exec --root . tool/ood-gen/bin/watch_scrape.exe > data/watch.yml

.PHONY: docker
docker: ## Generate docker container
	docker build -f Dockerfile . -t ocamlorg:latest
