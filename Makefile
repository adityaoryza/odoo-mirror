# odoo-mirror: developer tasks.   `make help` lists them.
SHELL := bash

SHELL_SOURCES := bin/odoo-mirror scripts/install.sh $(shell find lib -name '*.sh') $(shell find tests -name '*.sh')
LINT_ENTRY    := bin/odoo-mirror scripts/install.sh tests/run-unit.sh tests/integration/selftest.sh \
                 tests/integration/fake-remote/ssh tests/integration/fake-remote/sudo \
                 $(wildcard tests/unit/*.sh) $(wildcard tests/lib/*.sh)

.PHONY: help deps deps-dev lint test selftest install uninstall

help: ## show this help
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

deps: ## install the system packages listed in packages.apt (Ubuntu / Debian / WSL2, needs sudo)
	grep -vE '^\s*(#|$$)' packages.apt | xargs sudo apt install -y

deps-dev: ## install the Python development tools (ShellCheck) from requirements-dev.txt
	python3 -m pip install --user -r requirements-dev.txt

lint: ## syntax check, ShellCheck (follows every sourced module) and Python syntax
	bash -n $(SHELL_SOURCES)
	shellcheck -x $(LINT_ENTRY)
	python3 -c "import ast,sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]" lib/py/*.py

test: ## unit tests: no Odoo, no PostgreSQL, no server needed
	tests/run-unit.sh

selftest: ## full cycle against a fake server, needs a local Odoo (see CONTRIBUTING.md)
	tests/integration/selftest.sh

install: ## put `odoo-mirror` on your PATH (any shell). System-wide: make install PREFIX=/usr/local
	scripts/install.sh install $(if $(PREFIX),--prefix "$(PREFIX)")

uninstall: ## remove the command and the PATH lines added by `make install`
	scripts/install.sh uninstall $(if $(PREFIX),--prefix "$(PREFIX)")
