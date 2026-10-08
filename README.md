# odoo-mirror

**Mirror a remote Odoo database and its filestore to your own machine: safely, with progress, and neutralized.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Shell](https://img.shields.io/badge/shell-bash%20%E2%89%A5%204.4-4eaa25)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL2-lightgrey)
![Odoo](https://img.shields.io/badge/tested%20with-Odoo%2019-714B67)

### Install in one line

```bash
curl -fsSL https://github.com/adityaoryza/odoo-mirror/releases/latest/download/install.sh | bash
```

Then open a new terminal and run **`odoo-mirror`**: a menu asks what you want to do. The installer verifies the SHA-256 of the release and needs no `sudo`; `odoo-mirror update` keeps it current. To read the script first, or to install another way, see [Installation](#installation).

---

`odoo-mirror` is a Bash tool for Odoo developers and server managers. It connects to an Odoo
server over SSH, **streams** the database (plain SQL) and the filestore to your machine, builds a zip in
the exact format of the Odoo Database Manager, and restores it into a local database that is
**neutralized** (no e-mails, no crons) and cleaned of production credentials.

```
$ odoo-mirror backup --host myserver --remote-db prod_db

[3/5] Dump the database as plain SQL (streamed, gzip)
  sql.gz       ██████████████████████  96%  75.0 MB/77.9 MB  4.1 MB/s  ETA 00:00
[4/5] Download the filestore (streamed, no file on the server)
  filestore    ██████████████████████ 100%  2.7 GB/2.6 GB  6.4 MB/s
OK    6770 files received (matches the server)
[5/5] Build the Odoo-format zip (dump.sql + manifest.json + filestore)
  zip          ██████████████████████████████ 100%  3.2 GB/3.2 GB  6772 files
OK    2.5 GB → ~/odoo-mirror/prod_db/20261008-110732/prod_db_2026-10-08.zip
```

## Why

Copying a production database to a laptop is a daily task, and the usual ways have sharp edges:

| Usual way | The problem |
|---|---|
| Database Manager in the browser | The server builds the zip in `/tmp` first. On a nearly full disk it fails, or worse, leaves gigabytes of orphaned temporary files behind. |
| `pg_dump -Fc` | A dump made by PostgreSQL 17 cannot be read by a PostgreSQL 14 `pg_restore`. The filestore is not included. |
| Restoring a copy as is | The copy still holds the real SMTP credentials and active crons, and can send e-mails to real customers. |

`odoo-mirror` avoids all three: nothing is written on the server, the SQL is plain text, and the restore is neutralized
and verified.

## Features

- **Nothing written on the server.** Database and filestore are streamed over SSH.
- **One password prompt.** A single multiplexed SSH connection serves the whole run.
- **Odoo-compatible output.** The zip contains `dump.sql`, `manifest.json` and `filestore/`, and loads in the Database Manager or with `odoo-bin db load`.
- **Always neutralized.** A restore is never offered without neutralize (no e-mails, no crons): the wizard does not even ask. S3 keys and remote-backup targets are removed, and the result is verified.
- **Progress and logs.** Step counter, timings, progress bars with speed and ETA, and a log file per run.
- **Choose what runs.** Run everything, only the download, only the restore, or any list of steps.
- **Interactive or scripted.** A menu and a wizard when you give no arguments, flags and saved profiles for automation.
- **One-line install, self-updating.** Installs from a release with a verified checksum (`odoo-mirror update` keeps it current).
- **No secrets stored.** Passwords are never written to disk, to the log, or to the process list.
- **Real data or anonymized: your choice.** Customer data is kept by default; an optional flag anonymizes private individuals.

## How it works

```
 your machine                                     the Odoo server
┌──────────────────────────┐   one SSH connection  ┌──────────────────────────┐
│ odoo-mirror              │ ◄──────────────────── │ pg_dump --no-owner | gzip │
│                          │ ◄──────────────────── │ tar of the filestore      │
│  dump.sql + filestore/   │                       │   (nothing written here) │
│  → manifest.json → .zip  │                       └──────────────────────────┘
│  → odoo-bin db load -n   │
│  → sanitize → verify     │
└──────────────────────────┘
```

| Step | What happens |
|---|---|
| `connect` | Opens the SSH connection and checks `sudo`. |
| `inspect` | Reads the database and filestore sizes, finds the filestore, checks free disk space. |
| `dump` | `pg_dump --no-owner` as plain SQL, gzipped on the fly. Checks the archive. |
| `filestore` | `tar` streamed and extracted on the fly. Compares the file count with the server. |
| `assemble` | Builds and tests the zip. |
| `restore` | `odoo-bin db load -n <local-db> <zip>`. |
| `sanitize` | Removes S3 keys, disables remote backup targets, optional extra SQL. |
| `verify` | Checks neutralization, crons, outgoing mail, data and filestore. |
| `cleanup` | Removes the intermediate files. The zip and the log are kept. |

## Requirements

| | |
|---|---|
| Local machine | Linux or WSL2, `bash` ≥ 4.4, `ssh`, `python3` (standard library only), `gzip`, `tar`, `awk`, GNU coreutils |
| To restore | `psql` and a local Odoo with the `odoo-bin db` subcommand |
| Server | SSH access, and `sudo` (or a user that can run `pg_dump` and read the filestore) |
| Optional | `pv` for its progress bar (a built-in one is used otherwise), `unzip` |

### Install the prerequisites (Ubuntu / Debian / WSL2)

```bash
# needed to download a database and its filestore
sudo apt update && sudo apt install -y openssh-client python3 gzip tar gawk sed findutils coreutils

# needed to restore (a local Odoo and PostgreSQL server are yours to set up)
sudo apt install -y postgresql-client unzip

# optional: a nicer progress bar
sudo apt install -y pv

# only to work on odoo-mirror itself (make lint / make test / make selftest)
sudo apt install -y make shellcheck cpio git
```

The same list is in [`packages.apt`](packages.apt), so `make deps` installs it for you.
`requirements.txt` is empty on purpose: **no Python package is needed**, the tool uses the standard library only.
`requirements-dev.txt` holds the one development tool available from `pip` (ShellCheck), `make deps-dev`. The PostgreSQL client must be recent enough to read
dumps from current servers (14.19, 15.14, 16.10, 17.6 or later); the restore step checks this and tells you.

**Tested with:** Odoo 19 Enterprise, PostgreSQL 17 on the server and 14 client tools locally, Ubuntu 22.04 and WSL2.
macOS is not supported yet (GNU-specific options).

## Installation

### From a release (recommended)

```bash
curl -fsSL https://github.com/adityaoryza/odoo-mirror/releases/latest/download/install.sh | bash
```

The installer downloads the latest release, **checks its SHA-256** against `SHA256SUMS`, unpacks it under
`~/.local/share/odoo-mirror/` and links the `odoo-mirror` command into a folder of your `PATH` (it adds
`~/.local/bin` to your bash, zsh, `~/.profile` and fish configuration if needed, once). Nothing needs `sudo`.
Open a new terminal, then:

```bash
odoo-mirror
```

Prefer to read it first? Download the script, look at it, then run it:

```bash
curl -fsSLO https://github.com/adityaoryza/odoo-mirror/releases/latest/download/install.sh
less install.sh
bash install.sh
```

Useful options: `--prefix /usr/local` (every user, needs `sudo`), `--version v1.1.0` (a specific release).

### Update

```bash
odoo-mirror update           # install the newest release (checksum verified)
odoo-mirror update --check   # only say whether one exists
```

The previous release is kept, so you can go back by pointing `~/.local/share/odoo-mirror/current` to it.
A source checkout (below) is never touched by `update`: use `git pull` there.

### From a source checkout (to contribute)

```bash
git clone https://github.com/adityaoryza/odoo-mirror.git
cd odoo-mirror
bin/odoo-mirror check               # verifies the local prerequisites
make install                        # links this checkout as the command
```

`make install` works with any shell. `make install PREFIX=/usr/local` (with `sudo`) installs for every user. Run
`make uninstall` (or `scripts/install.sh uninstall`) to remove the command and the `PATH` lines it added; the
downloaded releases stay in `~/.local/share/odoo-mirror/` until you delete that folder.
For a shorter name, add `alias omr=odoo-mirror` to your shell configuration.

## Quick start

**Menu and wizard** (with no arguments: choose what to do, then every value is asked and you may save a profile):

```bash
odoo-mirror
```

The menu offers: mirror a database, back it up to a zip, restore a zip, list the databases on a server, run a saved
profile, check the machine, update, and help. It uses arrow keys and Enter when `whiptail` is installed (it is on
Ubuntu and WSL2), and a numbered list otherwise (`ODOO_MIRROR_MENU=plain` forces the list,
`ODOO_MIRROR_NO_MENU=1` skips the menu and goes straight to the wizard).

**Run a saved profile** (no questions, only the passwords):

```bash
odoo-mirror staging
```

**Download a database and its filestore** (nothing is restored):

```bash
odoo-mirror backup --host myserver --remote-db prod_db
```

**Restore it into a new local database** (neutralized):

```bash
odoo-mirror restore --zip ~/odoo-mirror/prod_db/<timestamp>/prod_db_<date>.zip --local-db prod_db_local
```

**Both in one go:**

```bash
odoo-mirror all --host myserver --remote-db prod_db --local-db prod_db_local
```

**See what is on the server first** (read-only):

```bash
odoo-mirror discover --host myserver
```

> The host can be an alias from `~/.ssh/config` (`Host myserver`, `Port`, `User`, `IdentityFile`) or given with `--host`, `--port`, `--user`, `--key`.

## Commands

| Command | Steps | Purpose |
|---|---|---|
| `all` (default) | all | Download, then restore. |
| `backup` | connect → inspect → dump → filestore → assemble | Produce the zip. |
| `restore` | restore → sanitize → verify → cleanup | Load an existing zip locally (`--zip`). |
| `discover` | connect, then a listing | Databases and filestores on the server. |
| `check` | none | Verify the local prerequisites. |
| `profiles` | none | List the saved profiles. |
| `update` | none | Install the newest release (`--check`: only look). |

Fine tuning: `--steps dump,assemble` runs only those steps, `--skip filestore` runs everything except it, and `--dry-run` prints the plan without doing anything.

## Options

**Server**

| Option | Meaning |
|---|---|
| `--host HOST` | SSH host or alias. |
| `--port N`, `--user U`, `--key FILE` | SSH port, user, identity file (optional). |
| `--remote-db NAME` | Database to back up. Leave it empty in the wizard to list the databases of the server and pick one (read only). |
| `--remote-fs-root DIR` | Directory that contains the filestore of that database. Empty means it is searched. |
| `--no-sudo` | Run `pg_dump` and `tar` without `sudo`. |
| `--pg-os-user USER` | Operating-system user that may run `pg_dump` (default `postgres`). |

**Local**

| Option | Meaning |
|---|---|
| `--local-db NAME` | Database to create (default `<remote-db>_local`). |
| `--out-dir DIR` | Where zips and logs go (default `~/odoo-mirror`). |
| `--odoo-bin FILE`, `--odoo-python FILE`, `--odoo-conf FILE` | Your local Odoo (detected when possible). |
| `--zip FILE` | Restore this zip instead of downloading. |
| `--workdir DIR` | Directory of this run. A run is not resumable yet. |
| `--odoo-version-tag TAG` | Value written in the manifest (default `19.0+e`). |

**Safety and data**

| Option | Meaning |
|---|---|
| `--no-neutralize` | Do not neutralize. Refused unless `--i-understand-emails-will-be-live` is also given. |
| `--no-sanitize` | Keep the S3 keys and remote backup targets of the copy. |
| `--anonymize` | Optional: replace the personal data of private individuals. |
| `--sanitize-sql FILE` | Extra SQL for your own modules, run on the copy. |
| `--force` | Replace the local database if it exists (you must type its name, or pass `--yes`). |
| `--keep-build` | Keep `dump.sql` and `filestore/`. |

**General**: `--profile NAME`, `--save-profile NAME`, `-y/--yes`, `--non-interactive`, `--dry-run`, `--version`, `-h/--help`.

## Configuration and profiles

Every value comes from, by priority: a **flag**, a **profile**, the **wizard**, a default.

To avoid typing the same answers again, the wizard ends by offering to **save them as a profile**. A profile remembers the
command too, so the saved name alone is enough:

```bash
odoo-mirror staging                        # repeats what was saved: only the passwords are asked
odoo-mirror all staging --local-db copy    # the same server, but download and restore
odoo-mirror profiles                       # list the saved profiles
```

`odoo-mirror staging` is the same as `odoo-mirror --profile staging`. Profile names cannot be a command word
(`all`, `backup`, `restore`, `discover`, `check`, `profiles`, `help`).

A profile is a plain `KEY="value"` file in `~/.config/odoo-mirror/profiles/<name>.conf`. It holds **non-secret** settings only
and is parsed against a whitelist: it is never executed. Create one with `--save-profile NAME` or copy
[`examples/profile.example.conf`](examples/profile.example.conf).

```bash
odoo-mirror --profile staging
```

### Environment variables

| Variable | Effect |
|---|---|
| `ODOO_MIRROR_HOME` | Where profiles and settings live (default `~/.config/odoo-mirror`). |
| `ODOO_MIRROR_MENU=plain` | Numbered menu instead of the `whiptail` one. |
| `ODOO_MIRROR_NO_MENU=1` | No menu: with no arguments, go straight to the wizard. |
| `ODOO_MIRROR_SUDO_PASSWORD` | sudo password for unattended runs (discouraged: prefer the hidden prompt). |
| `ODOO_MIRROR_REPO` | GitHub repository used by the installer and `update` (default `adityaoryza/odoo-mirror`). |
| `ODOO_MIRROR_PREFIX` | Where releases are unpacked (default `~/.local/share/odoo-mirror`). |

## Security model

| Secret | How it is handled |
|---|---|
| SSH password or passphrase | Asked by `ssh` itself, once. Key authentication and `ssh-agent` work as usual. |
| `sudo` password | Asked with a hidden prompt, sent through stdin only. Never in arguments, history, log or `ps`. `ODOO_MIRROR_SUDO_PASSWORD` exists for CI and is discouraged. |
| Local PostgreSQL credentials | Read from the `odoo.conf` you point to. |
| Profiles and logs | No secrets. Logs are created with mode `600`. |

Other safeguards: database names and paths are validated, the local target can never be the database your Odoo is configured with,
a restore without neutralize is refused, and partial files are removed when a run fails or is interrupted.

## Real data or anonymized

By default the restored copy keeps the **real customer data**, which is what you want to reproduce a case or to test with accurate
figures. Neutralize only stops e-mails and crons; it does not change the data.

When the copy must be shared, add the optional `--anonymize` (the wizard asks, default *no*). It replaces the name, e-mail, phones,
job title and notes of private individuals. Companies, intervention addresses and users are kept, so planning and history still work.
Chatter messages, attachments and photos are **not** anonymized. The SQL is in
[`sql/anonymize-persons.sql`](sql/anonymize-persons.sql): read it and adapt it to your own rules.

Whichever you choose, treat a copy with real data like the production data: encrypted disk, no shared drives or chats, delete it when
the test is over.

## What neutralize does not cover

Odoo's `neutralize` handles Odoo's own modules. Custom modules may keep credentials in `ir_config_parameter` or in their own tables.
`odoo-mirror` removes the `s3.*` parameters and disables the targets of the `db.backup.configure` model. Add the leftovers of your own
modules with `--sanitize-sql my_cleanup.sql`.

## Output

```
~/odoo-mirror/<remote-db>/<timestamp>/<remote-db>_<date>.zip     the backup
~/odoo-mirror/<db>/<timestamp>/odoo-load.log                     Odoo output of the restore
~/odoo-mirror/logs/odoo-mirror_<db>_<timestamp>.log              the run log
```

Exit status is `0` on success and non-zero otherwise (`130` when interrupted).

## Limitations

- Linux and WSL2 only. Tested with Odoo 19; other versions are unverified.
- A run cannot be resumed: an interrupted download starts again from the beginning.
- The database dump and the filestore are not taken atomically. Files that change in between are reported by the file count check.
- Integrity is checked with archive tests, an end-of-dump marker and a file count, not with a checksum compared to the server.
- The progress percentage of the SQL dump is an estimate (the compressed size is not known in advance).

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Connection timed out` | Wrong port (`--port`) or the server only accepts some IP addresses. |
| `sudo check failed` | Wrong password, or the user may not use `sudo` (try `--no-sudo`). |
| `The SQL dump is empty` | `pg_dump` did not run: wrong password, or `--pg-os-user`. |
| `Several candidates found` | Pass `--remote-fs-root` (use `discover` to see them). |
| `psql ... too old to read this dump` | Recent PostgreSQL dumps contain `\restrict`: update the client tools. |
| `read: -p: no coprocess` | You pasted bash lines into zsh. Run `odoo-mirror` itself: it starts with bash. |
| `Database not found` in your browser | Odoo serves only the database named in `db_name` of `odoo.conf`. Start a second instance with `-d <db> --http-port=8070`. |
| Hundreds of warnings during the restore | Normal for large code bases. They go to `odoo-load.log`. |

## Project layout

```
bin/odoo-mirror      entry point
lib/                 modules (logger, menu, input, ssh, local, plan, update, one file per step ...) and lib/py/ helpers
scripts/             install.sh (one-line installer, also used by `update`) and release.sh (builds a release)
sql/                 the SQL run on the restored copy
examples/            an example profile
tests/               unit tests, and an integration test with a fake server
docs/ARCHITECTURE.md how it is built, and how to add a step or an option
```

## Development

```bash
make lint        # bash -n, ShellCheck on every module, Python syntax
make test        # unit tests: no Odoo, no PostgreSQL, no server needed
make selftest    # a full cycle with a fake server, against one of your local databases
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before a larger change, and [CONTRIBUTING.md](CONTRIBUTING.md)
before opening a pull request.

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. To report a vulnerability, see
[SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Use it at your own risk: always verify a restored database before relying on it.
