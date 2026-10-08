# Architecture

This document explains how `odoo-mirror` is built, so that you can change it with confidence.
For *using* the tool, see the [README](../README.md).

## Layout

```
odoo-mirror/
├── scripts/
│   ├── install.sh             Installs the command for any shell: from a checkout, or from a release (checksum verified).
│   └── release.sh             Builds the release files in a local folder. Publishes nothing.
├── bin/odoo-mirror            Entry point: finds its modules, sets traps, calls main. Nothing else.
├── lib/
│   ├── odoo-mirror.sh         Loads every module below, in dependency order.
│   ├── globals.sh             Constants, defaults, runtime state. The only place with global variables.
│   ├── log.sh                 Logger, colors, step banners, die.
│   ├── progress.sh            Progress bar (pv or lib/py/progress.py) and the heartbeat spinner.
│   ├── menu.sh                The main menu (whiptail, or a numbered list). It only sets COMMAND and PROFILE.
│   ├── update.sh              `odoo-mirror update`: calls the installer of this copy to fetch the newest release.
│   ├── input.sh               ask / ask_yn / ask_secret and the wizard.
│   ├── profile.sh             Load and save profiles (parsed with a whitelist, never executed).
│   ├── cli.sh                 usage and parse_args (only sets variables).
│   ├── validate.sh            Validation of names, paths, configuration; preflight of the tools.
│   ├── local.sh               Local Odoo and PostgreSQL: odoo.conf, psql, dropping a database.
│   ├── ssh.sh                 SSH connection, rsudo/rpg (remote commands), filestore discovery.
│   ├── plan.sh                Which steps run, --steps/--skip, the plan shown before a run.
│   ├── config.sh              Fills missing values, prepares the output directory and the log.
│   ├── steps/                 One file per step: connect, inspect, dump, filestore, assemble,
│   │                          restore, sanitize, verify, cleanup.
│   ├── commands.sh            Commands that are not a run of steps (discover).
│   ├── runtime.sh             on_error, on_exit, install_traps.
│   ├── main.sh                main: the only function that wires the others together.
│   └── py/                    progress.py, build_zip.py (Python standard library only).
├── sql/                       sanitize.sql, anonymize-persons.sql (plain SQL, run with psql -f).
├── examples/                  profile.example.conf
├── tests/
│   ├── run-unit.sh            Runs tests/unit/test_*.sh, one process per file.
│   ├── lib/                   assert.sh (assertions), bootstrap.sh (loads the modules).
│   ├── unit/                  Pure-logic tests. No Odoo, PostgreSQL or server.
│   └── integration/           selftest.sh and fake-remote/ (ssh and sudo stand-ins).
├── docs/                      This file.
├── Makefile                   lint, test, selftest, install.
└── .github/workflows/ci.yml   make lint + make test on every push and pull request.
```

## Flow of a run

```
bin/odoo-mirror
  └─ main
       ├─ parse_args              flags → variables
       ├─ menu_main               only with no arguments and a terminal: what to do (command or profile)
       ├─ load_profile            profile values (a flag still wins)
       ├─ wizard                  only with no arguments and a terminal
       ├─ resolve_steps           command / --steps / --skip → ACTIVE_STEPS
       ├─ collect_config          ask for what is still missing
       ├─ validate_config         refuse anything unsafe, before touching anything
       ├─ make_workspace          output directory + log file (mode 600)
       ├─ print_plan              what is going to happen
       └─ for each active step: step_<name>
```

The steps share state through the variables of `globals.sh` (for example `REMOTE_DB_BYTES` is set by `inspect`
and read by `dump`). A step must be able to say what it needs: when a value is missing because a previous step
was skipped, it computes it or stops with a clear message (see `step_filestore`, which discovers the filestore
root when `inspect` did not run).

## Design decisions

| Decision | Why |
|---|---|
| **Stream, never stage on the server** | The usual cause of a failed backup is a full server disk. The server only runs `pg_dump` and `tar`; their output goes through SSH. |
| **Plain SQL, not `pg_dump -Fc`** | A custom-format archive made by PostgreSQL 17 cannot be read by `pg_restore` 14. Plain SQL is read by any `psql`, and it is what the Odoo zip contains. |
| **One multiplexed SSH connection** | One password prompt for the whole run, and the `sudo` password is checked once. |
| **`sudo` password through stdin** | Arguments are visible in `ps`, history and logs. Stdin is not. |
| **Python for the bars and the zip** | `pv` and `zip` are not always installed; Python is. Both programs are real files so that they can be linted and tested. |
| **SQL in `.sql` files** | They can be reviewed, linted by a SQL tool, and replaced by the user (`--sanitize-sql`). |
| **Profiles are parsed, not sourced** | Sourcing a file executes it. A profile is data. |
| **Explicit module list, not a glob** | The load order is visible, and ShellCheck can follow every `source`. |
| **Odoo's CLI for the restore** | `odoo-bin db load -n` is the supported way to load a dump with its filestore and to neutralize it. |

## Releases and updates

A release is three files: `odoo-mirror-vX.Y.Z.tar.gz` (the tool, with a `RELEASE` file holding the version),
`SHA256SUMS` and `install.sh`. `scripts/release.sh` builds them from the working tree.

`scripts/install.sh` (also shipped inside every release) unpacks a release to `~/.local/share/odoo-mirror/vX.Y.Z/`, points
`current` to it, and links the command to `current/bin/odoo-mirror`. It refuses an archive whose checksum does not
match or whose paths could leave the folder. `odoo-mirror update` just runs the installer of the copy you have, so the
logic exists once. A copy without a `RELEASE` file is a source checkout and is never updated.

The installer reads releases from GitHub, or from `ODOO_MIRROR_RELEASE_BASE` (a folder or URL with a `latest` file and one
folder per tag): that is what the tests use, so they need no network.

## Error handling

- `set -Eeuo pipefail` in the entry point; `ERR` is trapped (`on_error`) and reports the step that failed.
- A step writes to `*.part` files and renames them once checked. Files that are not final are listed in `PARTIAL_FILES`
  and removed by `on_exit` when the run did not succeed.
- `die MESSAGE` logs and exits with status 1. An interrupt exits with 130.
- `on_exit` always closes the SSH master connection and clears the `sudo` password variable.
- A command inside `if`, `&&` or `||` does not trigger `set -e`: when you write one, make sure a failure is handled.

## Security invariants

A change must keep all of these true (they are checked in review):

1. A secret never appears in an argument list, a log line, a file, or an environment variable we create.
2. A value from the user is validated (`valid_name`, `valid_path`) before it reaches a shell, a path or SQL.
3. Nothing is deleted or overwritten without an explicit option and a confirmation.
4. A restore is neutralized unless the user typed the long, explicit acknowledgement.
5. Nothing is written on the server.

## How to add a step

1. Name it (for example `checksum`) and add it to `ALL_STEPS` in `lib/globals.sh`, at its place in the order.
2. Create `lib/steps/checksum.sh` with a function `step_checksum`. Start with `step_begin checksum "Title"` and end with `step_end`.
3. Source it in `lib/odoo-mirror.sh`.
4. Add it to the right command in `resolve_steps` (`lib/plan.sh`), and to the `case` in `main` (`lib/main.sh`).
5. If it needs the server or a local restore, update `needs_remote` / `needs_local_restore` (`lib/plan.sh`).
6. Document it in the README table of steps and in [CHANGELOG.md](../CHANGELOG.md).
7. Add a unit test for the logic that does not need a server, and run `make selftest` for the rest.

## How to add an option

1. Give the variable its default in `lib/globals.sh`. If it may be saved in a profile, add it to `PROFILE_KEYS`.
2. Parse it in `parse_args` and describe it in `usage` (`lib/cli.sh`).
3. Validate it in `validate_config` when it reaches a shell, a path or SQL (`lib/validate.sh`).
4. Add it to the README options table, and test it in `tests/unit/test_cli.sh`.

## Testing strategy

| Level | What | Command |
|---|---|---|
| Static | `bash -n`, ShellCheck (from the entry point, so every module is analysed with its context), Python syntax | `make lint` |
| Unit | Pure logic: formatting, validation, argument parsing, step selection, profiles, `odoo.conf` parsing, the Python helpers | `make test` |
| Release | `release.sh`, a one-line install from a pipe, `update`, a tampered archive, `uninstall`, all against a local folder | `make test` |
| Integration | A full cycle (download, zip, restore, sanitize, verify) with fake `ssh` and `sudo`, against one of your local databases | `make selftest` |

The unit tests load the modules with `tests/lib/bootstrap.sh` and never start a run. Keep functions free of side
effects at load time so that this stays possible.
