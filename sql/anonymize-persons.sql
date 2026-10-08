-- odoo-mirror example: remove the personal data of private individuals from a restored copy.
--
--   odoo-mirror restore --zip X.zip --local-db copy --sanitize-sql sql/anonymize-persons.sql
--
-- What it does
--   * contacts that are people (not companies, not users): name, e-mail, phones, job title, notes
--   * companies and intervention addresses are kept: the planning and the maintenance
--     history depend on them.
-- What it does NOT do (do not rely on it as a complete anonymization)
--   * chatter messages, attachments, signatures and photos still hold personal data
--   * employees and technicians (res.users) keep their identity so the team can log in
--   * the filestore is not touched
-- Review it for your own rules before using it on a copy that leaves your machine.

UPDATE res_partner p
   SET name              = 'Contact ' || p.id,
       complete_name     = 'Contact ' || p.id,
       email             = 'contact' || p.id || '@example.invalid',
       email_normalized  = 'contact' || p.id || '@example.invalid',
       phone             = NULL,
       alternative_phone = NULL,
       function          = NULL,
       comment           = NULL,
       website           = NULL
 WHERE p.type = 'contact'
   AND NOT p.is_company
   AND NOT EXISTS (SELECT 1 FROM res_users u WHERE u.partner_id = p.id);
