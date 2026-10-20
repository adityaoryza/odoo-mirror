# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.3] - 2026-10-20

### Changed
- **The restored database is easy to find.** After a restore, the summary ends with the name of the local database on a bar of
  its own, between two rules, under the frame: black on green on a terminal, plain text with `=` rules without colors (a pipe,
  `NO_COLOR`). A backup run, which creates no database, shows nothing.

## [1.3.2] - 2026-10-19

### Added
- **Odoo version check.** The inspect step reads the Odoo version of the remote database and, when it is going to be restored,
  compares it with the local Odoo (`odoo-bin`). A different major version stops the run before anything is downloaded. The same
  check runs for `restore --zip` when the zip manifest records a version. `--allow-version-mismatch` turns the error into a warning.
  The failure frame says what to do (use the matching Odoo, or `--allow-version-mismatch`) instead of the generic hint of the step.
- **Local Odoo in the wizard.** The wizard shows the Odoo it detected (with its version) and asks `Use this Odoo?` when the
  paths were not given by a flag or a profile; `n` asks for `odoo-bin`, the Python interpreter and `odoo.conf`. The plan shows
  the local Odoo version.
- **Version mismatch rescue.** In a terminal, a version mismatch offers to look for an Odoo of the right major under the home
  folder (bounded, read only), lists the matches, validates the choice and continues the run; the profile in use can be updated
  with it. Without a terminal, or with `-y`, the run still stops with the same error.

### Fixed
- The manifest of the zip now records the Odoo version of the database, not the version of the local Odoo.

### Documentation
- Odoo 17 is now listed as tested (a 17.0 database restored with an Odoo 17 checkout, neutralized, verified and cleaned up).

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
