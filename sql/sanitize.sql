-- odoo-mirror: remove what points to production services from a restored copy.
-- Run by the `sanitize` step (disable with --no-sanitize). Safe to run twice.

-- object storage credentials: a copy must never reach the real bucket
DELETE FROM ir_config_parameter WHERE key ILIKE 's3.%';
-- remote backup targets (SFTP / FTP / Dropbox ...) and their credentials
DO $$
DECLARE c text;
BEGIN
    IF to_regclass('public.db_backup_configure') IS NULL THEN RETURN; END IF;
    FOREACH c IN ARRAY ARRAY['active'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'db_backup_configure' AND column_name = c) THEN
            EXECUTE format('UPDATE db_backup_configure SET %I = false', c);
        END IF;
    END LOOP;
    FOREACH c IN ARRAY ARRAY['master_pwd','sftp_password','ftp_password','dropbox_client_secret','dropbox_refresh_token'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'db_backup_configure' AND column_name = c) THEN
            EXECUTE format('UPDATE db_backup_configure SET %I = %L', c, 'neutralized');
        END IF;
    END LOOP;
END $$;
