# Contributing to odoo-mirror

Thank you for helping. This tool copies production data, so changes are reviewed with care: a small, well-tested
change is easier to accept than a large one.

## Before you start

- **Bugs and ideas:** open an issue first for anything bigger than a typo, so the approach can be agreed before you write code.
- **Security problems:** do not open a public issue, see [SECURITY.md](SECURITY.md).
- By submitting a contribution you agree that it is released under the project's [MIT license](LICENSE).

## Project principles

These are what a change is judged against:

1. **Nothing is written on the server.** Data is streamed.
2. **Safe by default.** Neutralize stays on, destructive actions need an explicit flag and a confirmation.
3. **No secret on disk, in the log, or on a command line.** Secrets go through stdin or a hidden prompt.
4. **Validate every value that reaches a shell.** Database names and paths are checked before use.
5. **Fail loudly and clean up.** A failed or interrupted run removes its partial files and says why.
6. **Dependencies stay minimal:** Bash and the standard tools. Python is used with its standard library only.

## Development setup

```bash
git clone <repository-url> odoo-mirror && cd odoo-mirror
make deps-dev                        # ShellCheck from pip; or: make deps (all system packages)
```

Before every pull request, both must pass:

```bash
make lint      # bash -n, ShellCheck on every module (followed from the entry point), Python syntax
make test      # unit tests: no Odoo, no PostgreSQL, no server needed
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first: it explains the modules, the design decisions, and how to add a step
or an option.

For a change that touches the download or the restore, also run the self-test. It uses fake `ssh` and `sudo` that execute the
"remote" commands locally, against one of **your own local databases**, then drops what it created:

```bash
SOURCE_DB=<a local db> SOURCE_FS=<its local filestore folder> \
ODOO_BIN=<odoo-bin> ODOO_PYTHON=<python> ODOO_CONF=<odoo.conf> \
make selftest
```

Never run an experiment against a server or a database you do not own.

## Style

- Bash ≥ 4.4, `set -Eeuo pipefail`, quote every expansion, `local` for function variables.
- One module per concern in `lib/`, one file per step in `lib/steps/` (function `step_<name>`). A module defines functions and
  constants only: nothing may run when it is sourced, so that the tests can load it.
- Global variables live in `lib/globals.sh` only. Messages go through `log_info`, `log_ok`, `log_warn`, `log_error`.
- SQL goes in `sql/*.sql`, Python in `lib/py/*.py`: not inside strings.
- A new option needs: a variable in `globals.sh`, a flag in `parse_args`, a line in `usage`, validation when it reaches a shell,
  a path or SQL, a row in the README options table, and a unit test (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)).
- Do not edit the code while a run is using it (Bash reads scripts as it executes them): run a copy.

## Commits and pull requests

- One logical change per pull request, with a short imperative title (`Add --foo`, `Fix empty dump detection`).
- Explain **why** in the description, and say how you tested it (the real command and what you saw).
- Update [CHANGELOG.md](CHANGELOG.md) under *Unreleased*.
- Keep the diff focused: no reformatting of untouched code.

## What is especially welcome

Unit tests for the remaining functions (see `tests/unit/`), macOS support, resumable downloads, checksum comparison with the
server, support for more Odoo versions (with the version you tested), and translations of the messages.
