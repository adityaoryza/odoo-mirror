# Security policy

`odoo-mirror` handles production databases, SSH sessions and `sudo` passwords, so security reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately through the repository's *Security → Report a vulnerability*
feature, or contact the maintainers directly. Include what you did, what you expected, what happened, and the version
(`odoo-mirror --version`). You will get an answer as soon as a maintainer can read it.

## Scope

Examples of what we want to know about:

- a secret (password, key, token) that reaches a file, a log, a process list, or the terminal history;
- a value (database name, path, option) that can inject a command on the local machine or on the server;
- an operation that can delete or overwrite something the user did not ask for;
- a restore that is not neutralized although it should be.

## Handling your own data

A restored copy contains real customer data unless `--anonymize` is used. Treat it like the production data: encrypted disk,
no shared drives or chats, delete it when you are done.
