# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
