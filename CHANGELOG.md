# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.1] - 2026-10-15

### Changed
- A calmer look: step titles with an accent arrow, labels of the plan and info marks dimmed, and the "done in" line of a step in
  a quiet tone. A dry run and commands without steps (`check`, `profiles`) no longer end with a summary frame.

### Fixed
- Icons that some terminals (Windows Terminal) draw as two-column emoji and overlap the text after them: the info, success,
  warning and error marks are now plain one-column symbols (`• ✓ ▲ ✗`).
- An SSH key file that does not exist (a stray `\` typed at the prompt, for example) is refused at once with a clear message,
  instead of an `Identity file ... not accessible` warning at every step.

## [1.3.0] - 2026-10-15

### Added
- **Clearer terminal output.** Icons for info, success, warning, error and step (`• ✓ ▲ ✗ ▶`) on a UTF-8 terminal, plain
  `INFO / OK / WARN / ERROR` labels everywhere else.
- **Run summary.** Every successful run ends with a frame: the steps with their duration, the warnings they raised, the name of
  the restored database (with its size and the `db_name` line to use) or the zip, and the log file. A dry run says so
  ("nothing was changed") instead of "Done".

### Changed
- A failed run is reported once, in one frame: the step, a hint on what to check, and the log file. This holds for the failures
  stopped by a step (for example an SSH connection that fails) as well as for a command that exits with an error. Ctrl+C is still
  reported as an interruption, not as a failure.
- Steps shorter than two seconds no longer print a line of their own, and a progress bar never leaves a half-drawn line behind.

## [1.2.0] - 2026-10-14

### Added
- **Automatic name of the local database.** `--local-db auto` (the default; in the wizard, an empty answer) names the copy
  `<server database>_<YYMMDD>`, then `_2`, `_3`... while that name is taken by a database, by a leftover filestore folder, or by
  the `db_name` of `odoo.conf`. The name is chosen once the server database is known, so it also works when it is picked from the list.
  A name typed by hand is used as it is, as before.
- `odoo.conf` is checked before the download: an option written twice (for example two `db_name` lines) stops Odoo at startup,
  so the run now refuses it at once, with the line numbers, instead of failing at the restore step after the download.

## [1.1.1] - 2026-10-14

### Fixed
- The filestore step no longer fails on a server that is in use. GNU `tar` exits with 1 when a file changes while it is read
  ("file changed as we read it"): the copy is complete, so it is now a warning, and the file count check that follows still
  reports a difference. A real `tar` error (exit 2) or a failure of the local side still stops the run.

## [1.1.0] - 2026-10-08

### Changed
- The single script is split into modules under `lib/` (one file per step in `lib/steps/`), with an entry point in `bin/`.
  The command line and the behaviour are unchanged.
- The embedded Python programs and SQL are now real files (`lib/py/`, `sql/`).

### Added
- A **main menu** when `odoo-mirror` starts with no arguments in a terminal (arrow keys with `whiptail`, a numbered list otherwise):
  mirror, back up, restore a zip, list the databases on a server, run a saved profile, check, update, help.
- **One-line installer** (`scripts/install.sh`) that installs a release after checking its SHA-256, and **`odoo-mirror update`**
  (`--check` to only look). The previous release is kept for a rollback; a source checkout is never updated this way.
- `scripts/release.sh` builds the release files (`odoo-mirror-vX.Y.Z.tar.gz`, `SHA256SUMS`, `install.sh`) locally and prints the
  commands to publish them. It publishes nothing itself.
- Tests for the menu and for the release, install and update cycle (all local: no network, no server).
- Leave the remote database name empty (interactive) and the tool lists the databases of the server, with their size, to pick from. It is one read-only `SELECT` on `pg_database`; `discover` uses the same query.
- `make install` (`scripts/install.sh`) works with bash, zsh, fish and sh: it uses a folder already in `PATH`, or adds `~/.local/bin` to the rc files once. `PREFIX=/usr/local` installs system-wide.
- `odoo-mirror <profile>`: a saved profile is a command of its own, and it remembers its command (`backup`, `all`...).
  New `profiles` command. Profile names cannot be a command word.
- The wizard offers to save the answers as a profile.
- Unit tests that need no Odoo, PostgreSQL or server (`make test`), `make lint`, `make install`, and a CI workflow.
- `docs/ARCHITECTURE.md`.

## [1.0.0] - 2026-10-08

### Added
- `backup`, `restore`, `all`, `discover` and `check` commands.
- Streaming of the database (plain SQL, gzip) and of the filestore over one multiplexed SSH connection. Nothing is written on the server.
- Zip in the Odoo Database Manager format (`dump.sql`, `manifest.json`, `filestore/`) with an integrity test.
- Neutralized restore, removal of S3 keys, disabling of remote backup targets, and a verification step.
- Wizard, flags, saved profiles, `--steps` / `--skip`, `--dry-run`.
- Step counter, timings, progress bars with speed and ETA, and a log file per run.
- Optional `--anonymize` for private individuals, and `--sanitize-sql` for custom cleanups.
- Guards: validated names and paths, refusal to overwrite the configured Odoo database, refusal to restore without neutralize.
